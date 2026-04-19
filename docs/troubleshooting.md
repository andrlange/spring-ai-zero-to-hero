# Troubleshooting

Common issues and how to fix them.

---

## Vector store dimension mismatch

**Symptom:** Vector store load endpoints fail with an error about dimension mismatch, or Spring fails to start when the `pgvector` profile is active.

**Cause:** You switched embedding models. The pgvector table stores dimensions at creation time and cannot change. For example, if you previously used `mxbai-embed-large` (1024 dims) and switched to `nomic-embed-text` (768 dims), the table schema is incompatible.

**Fix:** Drop the table. Spring AI will recreate it with the correct dimensions on next startup.

```bash
docker exec postgres-postgres-1 \
  psql -U postgres -d ollama -c "DROP TABLE IF EXISTS vector_store CASCADE;"
```

Replace `ollama` with the database name for your provider (`openai`, `azure`, etc.).

After dropping the table, restart the provider app. Spring AI will create a fresh table at 768 dimensions.

---

## "Call /load before /query" — empty results from RAG or vector search

**Symptom:** RAG query endpoints return empty results or the AI says it has no relevant information.

**Cause:** The vector store is empty. Documents must be loaded before similarity search works.

**Fix:** Always call the load endpoint first:

```bash
# For vector store demo
curl "http://localhost:8080/vector/01/load"

# For RAG demos
curl "http://localhost:8080/rag/01/load"
curl "http://localhost:8080/rag/02/load"
```

Then call the query endpoint. With the `pgvector` profile, loaded data persists across restarts. With the default in-memory `SimpleVectorStore`, you must reload after every restart.

---

## pgvector profile required for vector and RAG demos

**Symptom:** Vector store or RAG demos work once but data is lost after restart. Or errors about missing Spring beans.

**Cause:** Running without the `pgvector` profile uses `SimpleVectorStore`, which is in-memory only.

**Fix:** Start the provider app with the `pgvector` profile:

```bash
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation
```

Make sure Docker is running and PostgreSQL is started:

```bash
docker compose -f docker/postgres/docker-compose.yaml up -d
docker ps | grep postgres
```

---

## Ollama RAM requirements

**Symptom:** Ollama is slow, models fail to load, or your machine becomes unresponsive.

**Cause:** Running large models close to or above available RAM forces heavy swap usage.

**Model RAM requirements:**

| Model | RAM needed |
|-------|-----------|
| qwen3 (8B) | ~8 GB |
| nomic-embed-text | ~1 GB |
| llava (7B) | ~8 GB |
| llama3.2 (3B) | ~4 GB |

**Recommendations:**

- On 8 GB machines: run `qwen3` + `nomic-embed-text` only (~10 GB combined — tight but usually works). Avoid loading `llava` at the same time.
- On 16 GB machines: `qwen3` + `nomic-embed-text` leave ~6 GB free for the OS and Docker.
- Close other applications to free RAM before starting Ollama with large models.

**To check which models are currently loaded:**

```bash
ollama ps
```

**To unload a model:**

```bash
ollama stop qwen3
```

---

## Docker resource allocation

**Symptom:** Containers crash, run out of memory, or Docker Desktop is slow.

**Cause:** Default Docker Desktop memory limits are often too low for running PostgreSQL, Grafana LGTM, and Ollama simultaneously.

**Fix:** Increase Docker Desktop resource limits:

1. Open Docker Desktop > Settings > Resources
2. Set Memory to at least 8 GB (16 GB recommended)
3. Set CPUs to 4 or more
4. Disk image size: 20 GB minimum

For Colima on macOS:

```bash
colima start --memory 8 --cpu 4
```

---

## Embedding model context window limit

**Symptom:** `embed_03/big` returns a 200 response but with an error message instead of an embedding vector. The Shakespeare document cannot be embedded.

**Cause:** `nomic-embed-text` has an 8192 token context window. The full Shakespeare works far exceed this limit.

**This is expected behavior** — the endpoint is a demonstration of the limit, not a bug.

**Fix for your own documents:** Use `TokenTextSplitter` to chunk large documents before embedding. See the `embed_03/chunk` endpoint and `embed_04` document reader endpoints for working examples.

---

## Structured output fails with small models

**Symptom:** `chat_04/plays/object` returns malformed JSON or fails with a parse error when using `llama3.2`.

**Cause:** Structured output (JSON schema conformance) requires a capable model. `llama3.2` (3B) is too small to reliably follow JSON schema constraints.

**Fix:** Use `qwen3` (8B) as the default chat model for Ollama, which is the configured default in `applications/provider-ollama`. Qwen3 provides reliable structured output, tool calling, and reasoning — capabilities that smaller models like `llama3.2` lack.

---

## Tool calling unreliable with small models

**Symptom:** `chat_05/weather` or `chat_05/search` return a plain text response instead of invoking the tool, or fail.

**Cause:** Tool calling requires a model that follows function-calling protocols. `llama3.2` (3B) does not reliably support this.

**Fix:** Use `qwen3` (8B) — the configured default for provider-ollama. Qwen3 reliably follows function-calling protocols, unlike Mistral (7B) which often describes tool calls instead of executing them.

---

## Agentic agent apps require OpenAI

**Symptom:** Stage 7 agent REST endpoints fail or refuse to start when using `provider-ollama` or another non-OpenAI provider.

**Cause:** The agentic agent applications (`agentic-system/01-inner-monologue` and `agentic-system/02-model-directed-loop`) use `OpenAiChatOptions.toolChoice("required")`, which is OpenAI-specific.

**Fix:** Run the agentic agent REST apps with an OpenAI API key configured. The CLI modules (`inner-monologue-cli`, `model-directed-loop-cli`) are provider-agnostic and work with any provider.

---

## Observability not showing traces

**Symptom:** Grafana is running but no traces appear in Tempo after hitting endpoints.

**Causes and fixes:**

1. **Missing `observation` profile** — restart the provider app with `-Dspring-boot.run.profiles=pgvector,observation`
2. **LGTM container not running** — `docker ps | grep lgtm` and start it if needed
3. **OTLP endpoint not reachable** — test with `curl -sf http://localhost:4318/v1/traces`
4. **Datasource UID mismatch** — the pre-provisioned dashboards expect datasource UIDs `loki`, `prometheus`, `tempo`. These match the defaults for `grafana/otel-lgtm`. If you are running a custom Grafana setup, verify the UIDs match.

---

## Google provider dependency conflicts

**Symptom:** Provider-google fails at startup with `NoSuchMethodError` related to `okio` or `okhttp`.

**Cause:** The Google AI SDK ships with okhttp 4.x / okio 2.x, which conflicts with Spring Boot 4's okhttp 5.x / okio 3.x.

**Status:** This conflict is already fixed in the repository via explicit version overrides in `applications/provider-google/pom.xml`. If you see this error, ensure you are using the latest version of the project and that Maven dependency overrides are applied (run `./mvnw clean verify` to force a fresh resolution).

---

## Micrometer metric names in Grafana dashboards

**Symptom:** Some Grafana dashboard panels show "No data" even though the application is running and sending metrics.

**Cause:** Micrometer 1.16 (included in Spring Boot 4) changed metric naming: `*_seconds_*` became `*_milliseconds_*`.

**Fix:** If you are using custom dashboards or queries, update metric names accordingly. The pre-provisioned dashboards in `docker/observability-stack/` are already updated.

---

## Stage 6 / MCP

### Port 8081 / 8082 / 8083 already in use

```
fail  Port 8081 already in use
info  Free the port: lsof -ti:8081 | xargs kill
```

**Cause:** Another process bound to the MCP port (common if a previous run didn't shut down cleanly). **Fix:** run the hint above, or `./workshop.sh stop` to cleanup everything.

### `workshop.sh mcp start NN` times out

The MCP server didn't reach its port within 90s. Inspect the log:

```bash
./workshop.sh mcp logs NN
```

Usual culprits: Maven build failure, missing creds for the provider app that the MCP server depends on (03/04 clients need OpenAI creds), or bind failure.

### Dashboard shows MCP server `not running`

The status pill polls every 3 seconds via a TCP port probe. If the server is actually up:

1. Check `nc -z localhost 8081 && echo OK` from the host — should print `OK`.
2. Check the dashboard has the `ui` profile active — `./workshop.sh mcp status` should succeed.
3. Confirm `spring-ai-starter-mcp-client` is on the classpath: `./mvnw -pl components/config-dashboard dependency:tree | grep mcp-client`.

### 01 STDIO jar missing

Dashboard shows `./workshop.sh mcp build-01`. Run that command — it builds `mcp/01-mcp-stdio-server/target/01-mcp-stdio-server-0.0.1-SNAPSHOT.jar`. Re-open the card after ~15s.

### 04 "Trigger dynamic registration" has no further effect

04's server uses a one-shot `CountDownLatch`. To repeat the demo, restart the server: `./workshop.sh mcp stop 04 && ./workshop.sh mcp start 04`, then click Trigger again on a fresh server process.

---

## Stage 7 / Agentic

| Symptom | Cause | Fix |
|---|---|---|
| Card status pill stays gray | Agent process not running | `./workshop.sh agentic start 01\|02` |
| `Port 8091 already in use` | Stale process from previous run | `lsof -ti:8091 \| xargs kill` |
| `Port 8080 already in use` | That's the provider app / dashboard — **not** a Stage 7 concern. Stage 7 agents listen on `:8091` and `:8092` only | Free `:8080` for the provider app; agent apps are unaffected |
| Send returns `provider-error` | OpenAI 401 or Ollama unreachable | Check `creds.yaml` or `ollama serve` |
| Fallback ⚠ badge on every message | Model can't drive tool calls | Switch to `qwen3` (Ollama) or OpenAI |
| Demo 02 loop stops on first fallback | By design (spec decision D7) | Use a stronger model, or accept as a teaching moment |
| Traces missing from Grafana | `observation` profile not active, or OTel collector down on `:4318` | `./workshop.sh agentic start all --profile=openai,observation`; check LGTM stack |
| Gateway `/ollama` route reachable but 404 downstream | Ollama itself not running | `ollama serve` + `ollama pull qwen3` |
| `spy` + Ollama not capturing traffic | Profile not active | Use `--profile=ollama,spy,observation` |

See also: `SPRING_AI_STAGE_7.md § Ollama fallback behavior`.

---

## Dockerized Ollama

### Port 11434 in use — both native and dockerized Ollama

Only one can own port 11434 at a time. Check which is running:

```bash
./workshop.sh status | grep -oE 'ollama:[a-z]+'
```

Stop the one you don't want:

```bash
# macOS native — right-click the Ollama menu-bar icon → Quit
# Or force-kill
pkill -x ollama

# Dockerized
docker compose -f docker/ollama/docker-compose.yaml down
```

### Dockerized Ollama container runs but `ollama list` is empty

The `/root/.ollama/models` mount isn't finding models. Confirm and fix:

```bash
ls models/ollama/manifests        # should list registry.ollama.ai
docker compose -f docker/ollama/docker-compose.yaml down
docker compose -f docker/ollama/docker-compose.yaml up -d
docker exec ollama ollama list
```

On SELinux (Fedora/RHEL):
`chcon -Rt svirt_sandbox_file_t models/ollama`.

On rootless Docker, ensure `models/ollama/` is owned by your user.

### Slow inference inside the dockerized Ollama

Expected on macOS — containers can't access Metal, so inference is
CPU-only and typically 3–10× slower than native `Ollama.app`. On
Linux+NVIDIA, add the GPU overlay:

```bash
docker compose -f docker/ollama/docker-compose.yaml \
               -f docker/ollama/docker-compose.gpu.yaml up -d
```

See [docs/ollama_dockerized.md](ollama_dockerized.md) for detail.
