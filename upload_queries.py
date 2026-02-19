"""Upload example queries to Mentiora as trace events."""
import json
import os
from datetime import datetime, timezone
from uuid_utils import uuid7
from mentiora import MentioraClient, MentioraConfig, TraceEvent

API_KEY = os.environ.get("MENTIORA_API_KEY", "")
if not API_KEY:
    raise SystemExit("Set MENTIORA_API_KEY environment variable")
NDJSON_PATH = "from_prompt.ndjson"

config = MentioraConfig(api_key=API_KEY, debug=True)
client = MentioraClient(config)

with open(NDJSON_PATH) as f:
    queries = [json.loads(line)["query"] for line in f if line.strip()]

print(f"Sending {len(queries)} queries as trace events...")

errors = 0
for i, query in enumerate(queries):
    now = datetime.now(timezone.utc).isoformat()
    event = TraceEvent(
        trace_id=str(uuid7()),
        span_id=str(uuid7()),
        name="example_query",
        type="custom",
        input={"query": query},
        output={"status": "example_dataset"},
        start_time=now,
        end_time=now,
        duration_ms=0,
        tags=["dataset", "from_prompt"],
        metadata={"index": i, "source": "from_prompt.ndjson"},
    )
    result = client.tracing.send_trace(event)
    status = "OK" if result.success else f"FAIL: {result.error}"
    if not result.success:
        errors += 1
    print(f"  [{i+1}/{len(queries)}] {status} — {query[:60]}")

client.close()
print(f"\nDone. {len(queries) - errors}/{len(queries)} sent successfully.")
