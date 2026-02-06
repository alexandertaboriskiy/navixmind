# NavixMind

**A high-agency AI console agent for Android with local code execution.**

NavixMind embeds a Python 3.10 runtime directly inside the APK, enabling iterative, multi-step tasks that cloud-based AI apps cannot perform. Process files, execute logic, and automate workflows — all on-device.

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
┌─────────────────────────────────────────────────────────┐
│                    Flutter UI                            │
│              (Cyber-Clean dark theme)                    │
├─────────────────────────────────────────────────────────┤
│                  Kotlin Bridge                           │
│         (MethodChannel / EventChannel)                   │
├─────────────────────────────────────────────────────────┤
│              Python 3.10 (Chaquopy)                      │
│    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│    │ ReAct Agent │  │   Tools     │  │  Libraries  │   │
│    │ (Claude AI) │  │ (Web, PDF,  │  │ (requests,  │   │
│    │             │  │  Calendar)  │  │  pypdf...)  │   │
│    └─────────────┘  └─────────────┘  └─────────────┘   │
├─────────────────────────────────────────────────────────┤
│                Native Tools (Flutter)                    │
│         FFmpeg  │  Face Detection  │  WebView           │
└─────────────────────────────────────────────────────────┘
```

**Key design decisions:**
- **Python runs inside the APK** — no server, no cloud dependency
- **Native tools for performance** — FFmpeg runs on Flutter side
- **JSON-RPC bridge** — clean separation between Python logic and native execution
- **ReAct agent loop** — Claude reasons, acts, observes, repeats

### Why Android Only (For Now)?

NavixMind relies on [Chaquopy](https://chaquo.com/chaquopy/) to embed a full Python runtime inside the APK. This technology is Android-specific.

The same architecture could work on iOS with slightly alternative approaches for embedding Python. Apple's App Store has different guidelines around code execution, so the path forward looks a bit different. Would be interesting to explore that as well.

## Features

- **Video/Audio Processing** — crop, resize, extract audio, convert formats (FFmpeg)
- **Document Handling** — read/create PDFs, convert DOCX
- **Web Integration** — fetch pages, headless browser for JS-heavy sites
- **Google Services** — Calendar and Gmail integration (optional)
- **Offline Capable** — PDF reading, file management work without internet
- **Self-Improvement** — the agent can analyze successful workflows and update its own system prompt to handle similar requests better next time (opt-in, updates prompt file only — not the app binary)
- **Your API Key** — bring your own Claude API key

## Getting Started

### Prerequisites

- Android device (API 24+) — iOS support is possible in the future
- [Claude API key](https://console.anthropic.com/) from Anthropic

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

# Build debug APK
export JAVA_HOME="/path/to/jdk17"
flutter build apk --debug

# Install on connected device
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### First Run

1. Launch NavixMind
2. Accept Terms of Service and Privacy Policy
3. Enter your Claude API key (get one at [console.anthropic.com](https://console.anthropic.com/))
4. Start chatting!

## Configuration

Access Settings (gear icon) to configure:

| Setting | Description | Default |
|---------|-------------|---------|
| Preferred Model | Claude model (auto/opus/sonnet/haiku) | auto |
| Tool Timeout | Max seconds per tool execution | 30s |
| Max Steps | Reasoning steps before stopping | 50 |
| Max Tool Calls | Tool executions per query | 50 |
| Daily Token Limit | Cost control | 100,000 |

## Project Structure

```
navixmind/
├── lib/                    # Flutter/Dart code
│   ├── app/               # App setup, theme, routes
│   ├── core/              # Bridge, services, database
│   └── features/          # UI screens (chat, settings, legal)
├── python/                 # Python agent code
│   └── navixmind/         # ReAct agent, tools, utilities
├── android/               # Android native code
│   └── app/src/main/kotlin/  # Kotlin bridge, services
├── test/                  # Flutter tests
└── www/                   # Website (navixmind.ai)
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | Flutter 3.x |
| Python Runtime | Chaquopy |
| AI | Claude API (Anthropic) |
| Video/Audio | FFmpeg Kit |
| Database | Isar |
| Secure Storage | Flutter Secure Storage |

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
