# NavixMind

**A high-agency AI console agent for Android with local code execution and fully offline inference.**

NavixMind embeds a Python 3.10 runtime directly inside the APK, enabling iterative, multi-step tasks that cloud-based AI apps cannot perform. Process files, execute logic, and automate workflows — all on-device. With on-device LLM support via MLC, NavixMind can operate entirely offline — no API key, no internet connection required.

## Why NavixMind?

Current mobile AI apps run on a "remote runtime" model. They're great for chat, but fail when tasks require:
- **Iterative loops** — checking results and retrying with adjusted parameters
- **Local file manipulation** — without uploading to cloud sandboxes
- **Multi-step workflows** — combining multiple tools in sequence

NavixMind fixes this by running Python locally via [Chaquopy](https://chaquo.com/chaquopy/), with Claude AI orchestrating the logic.

### Example Use Cases

| Task | Cloud AI Apps | NavixMind |
|------|---------------|-----------|
| "Compress this video to under 25MB with best quality" | One-shot attempt, no feedback loop | Runs FFmpeg iteratively, adjusting bitrate until target is met |
| "Split this recording into 10-min MP3 segments and zip them" | Requires uploading huge files | Processes in-place, on-device |
| "Generate a PDF summary for each meeting tomorrow" | Cannot create/save files locally | Creates files directly on your phone |

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       Flutter UI                              │
│                 (Cyber-Clean dark theme)                       │
├──────────────────────────────────────────────────────────────┤
│                     Kotlin Bridge                              │
│            (MethodChannel / EventChannel)                      │
├──────────────┬───────────────────────────────────────────────┤
│  MLC LLM     │           Python 3.10 (Chaquopy)               │
│  Engine      │  ┌─────────────┐ ┌──────────┐ ┌───────────┐  │
│  (On-Device) │  │ ReAct Agent │ │  Tools   │ │ Libraries │  │
│  ┌─────────┐ │  │ Claude API  │ │ (Web,    │ │ (requests,│  │
│  │ Qwen2.5 │◄├──┤   — or —   │ │  PDF,    │ │  pypdf,   │  │
│  │ Coder   │ │  │ Local LLM  │ │  FFmpeg) │ │  pandas)  │  │
│  └─────────┘ │  └─────────────┘ └──────────┘ └───────────┘  │
├──────────────┴───────────────────────────────────────────────┤
│                   Native Tools (Flutter)                       │
│          FFmpeg  │  OCR (ML Kit)  │  File Sharing              │
└──────────────────────────────────────────────────────────────┘
```

**Key design decisions:**
- **Python runs inside the APK** — no server, no cloud dependency
- **Dual inference paths** — Claude API (cloud) or MLC LLM (on-device), user's choice
- **Native tools for performance** — FFmpeg runs on Flutter side
- **JSON-RPC bridge** — clean separation between Python logic and native execution
- **ReAct agent loop** — model reasons, acts, observes, repeats (works with both cloud and local models)

### Why Android Only (For Now)?

NavixMind relies on [Chaquopy](https://chaquo.com/chaquopy/) to embed a full Python runtime inside the APK. This technology is Android-specific.

The same architecture could work on iOS with slightly alternative approaches for embedding Python. Apple's App Store has different guidelines around code execution, so the path forward looks a bit different. Would be interesting to explore that as well.

## Features

- **Fully Offline AI** — run Qwen2.5-Coder models (0.5B/1.5B/3B) on-device via MLC LLM, no internet required
- **Cloud AI** — or use Claude API (Opus/Sonnet/Haiku) for maximum capability
- **Video/Audio Processing** — crop, resize, extract audio, convert formats, adjust volume (FFmpeg)
- **Document Handling** — read/create PDFs, convert DOCX, Excel, PowerPoint
- **Web Integration** — fetch pages, headless browser for JS-heavy sites
- **Google Services** — Calendar and Gmail integration (optional)
- **Data Analysis** — pandas and matplotlib for data processing and visualization
- **Self-Improvement** — the agent can analyze successful workflows and update its own system prompt to handle similar requests better next time (opt-in, updates prompt file only — not the app binary)
- **Your Choice** — bring your own Claude API key, or use offline models with zero cloud dependency

## On-Device LLM (Offline Mode)

NavixMind can run entirely offline using on-device language models powered by [MLC LLM](https://llm.mlc.ai/). No API key, no internet connection — the model runs directly on your phone's GPU.

### Available Models

| Model | Size | RAM Required | Best For |
|-------|------|-------------|----------|
| Qwen2.5-Coder-0.5B | ~400MB | 2GB+ | Quick tasks, low-end devices |
| Qwen2.5-Coder-1.5B | ~1GB | 4GB+ | Balanced speed and quality |
| Qwen2.5-Coder-3B | ~2GB | 6GB+ | Best quality, tool-use capable |

Models are quantized to `q4f16_0` (4-bit weights, 16-bit activations) for efficient mobile inference.

### How It Works

1. **Download once** — select a model in Settings, it downloads from HuggingFace (with resume support)
2. **Load on demand** — model loads into GPU memory when you send a message (~10-30s first load)
3. **Full tool support** — the ReAct agent loop works identically to cloud mode: the model can call Python, FFmpeg, OCR, and all other tools
4. **Malformed JSON repair** — small models sometimes produce incomplete JSON in tool calls; the agent automatically repairs missing closing braces

### Architecture (Offline Path)

```
User message
    │
    ▼
Flutter (LocalLLMService)
    │
    ├──► Kotlin (MLCInferenceChannel)
    │        │
    │        ▼
    │    MLC LLM Engine (GPU)
    │        │
    │        ▼
    │    OpenAI-format response
    │        │
    ▼        ▼
Python Agent (ReAct loop)
    │
    ├──► Tool calls (python_execute, ffmpeg_process, etc.)
    │        │
    │        ▼
    │    Native Tool Executor (Flutter)
    │        │
    ▼        ▼
    Response to user
```

The on-device model generates OpenAI-compatible responses which the Python agent converts to Claude-compatible format, allowing the same ReAct tool-use loop to work with both cloud and local models.

## Getting Started

### Prerequisites

- Android device (API 24+) — iOS support is possible in the future
- **Cloud mode:** [Claude API key](https://console.anthropic.com/) from Anthropic
- **Offline mode:** No API key or internet needed — download an on-device model from Settings

### Installation

**Option A: Download APK**
- Get the latest APK from [GitHub Releases](https://github.com/alexandertaboriskiy/navixmind/releases)

**Option B: Google Play** (coming soon)
- Will be available once submitted to Play Store

**Option C: Build from source**

```bash
# Clone the repository
git clone https://github.com/alexandertaboriskiy/navixmind.git
cd navixmind

# Install Flutter dependencies
flutter pub get

# Build MLC LLM native libraries (required for on-device inference)
# Prerequisites: cmake, rust, Android NDK 27+, mlc_llm Python package
pip install --pre -U -f https://mlc.ai/wheels mlc-llm-nightly mlc-ai-nightly
mlc_llm package --config mlc-package-config.json
cp -r dist/lib/mlc4j/ android/mlc4j/

# Build debug APK
export JAVA_HOME="/path/to/jdk17"
flutter build apk --debug

# Install on connected device
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### First Run

1. Launch NavixMind
2. Accept Terms of Service and Privacy Policy
3. Choose your AI mode:
   - **Cloud mode:** Enter your Claude API key (get one at [console.anthropic.com](https://console.anthropic.com/))
   - **Offline mode:** Go to Settings → On-Device Models, download a model
4. Start chatting!

## Configuration

Access Settings (gear icon) to configure:

| Setting | Description | Default |
|---------|-------------|---------|
| AI Mode | Cloud (Claude API) or Offline (on-device) | Cloud |
| Preferred Model | Claude model (auto/opus/sonnet/haiku) | auto |
| On-Device Model | Local model (0.5B/1.5B/3B) | — |
| Tool Timeout | Max seconds per tool execution | 30s |
| Max Steps | Reasoning steps before stopping | 50 |
| Max Tool Calls | Tool executions per query | 50 |
| Daily Token Limit | Cost control (cloud mode only) | 100,000 |

## Project Structure

```
navixmind/
├── lib/                       # Flutter/Dart code
│   ├── app/                  # App setup, theme, routes
│   ├── core/
│   │   ├── bridge/           # Python↔Flutter JSON-RPC bridge
│   │   ├── models/           # Model registry (on-device LLM catalog)
│   │   └── services/         # LocalLLMService, NativeToolExecutor, StorageService
│   └── features/             # UI screens (chat, settings, legal)
├── python/                    # Python agent code
│   └── navixmind/            # ReAct agent, tools, local LLM client
├── android/
│   ├── app/src/main/kotlin/  # Kotlin bridge, MLC inference, model downloads
│   └── mlc4j/                # MLC LLM native library (built via mlc_llm package)
├── test/                     # 2,167 Dart tests
├── python/tests/             # 950 Python tests
└── www/                      # Website (navixmind.ai)
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | Flutter 3.x |
| Python Runtime | Chaquopy |
| Cloud AI | Claude API (Anthropic) |
| On-Device AI | MLC LLM + Qwen2.5-Coder (q4f16_0) |
| Video/Audio | FFmpeg Kit |
| Database | Isar |
| Secure Storage | Flutter Secure Storage |
| Model Downloads | OkHttp (chunked, resumable) |

## Development

### Running Tests

```bash
# Flutter tests
flutter test

# Python tests
cd python && pytest
```

### Building Release

```bash
flutter build appbundle --release
```

### Debug Logging

```bash
adb logcat -s flutter,PythonBridge,NativeToolResponse
```

## Privacy & Data

See [Privacy Policy](https://navixmind.ai/privacy.html) for full details.

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

For bugs or feature requests, [open an issue](https://github.com/alexandertaboriskiy/navixmind/issues).

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.

## Links

- **Website:** [navixmind.ai](https://navixmind.ai)
- **Issues:** [GitHub Issues](https://github.com/alexandertaboriskiy/navixmind/issues)
- **Contact:** support@navixmind.ai
