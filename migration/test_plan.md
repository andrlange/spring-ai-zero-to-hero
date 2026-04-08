# Test & Evaluation Plan — Spring AI Workshop (Post-Migration)

## Context

The project has been migrated to Spring Boot 4.0.5 + Spring AI 2.0.0-M4 + Java 25. We need to:
1. **Validate every demo endpoint** works correctly with Ollama (primary provider)
2. **Evaluate each stage** for correctness, response quality, and runtime behavior
3. **Capture UI improvement ideas** as we test each demo
4. **Validate observability** (LGTM stack, dashboards, distributed tracing)
5. **Produce a UI improvement plan** covering: web dashboard, Swagger/OpenAPI, CLI enhancements

## Test Provider: Ollama (local)
- Chat model: `qwen3`
- Embedding model: `mxbai-embed-large` (1024 dims)
- Multimodal: `llava` (optional, for chat_07)

## Note: Gateway port 7777 conflicts with local Spring MCP server — shut down MCP server before gateway tests.

---

## Phase 0: Infrastructure Setup

### 0.1 Start Docker infrastructure
```bash
docker compose -f docker/postgres/docker-compose.yaml up -d
docker compose -f docker/observability-stack/docker-compose.yaml up -d
```

### 0.2 Verify infrastructure
- [ ] PostgreSQL: `psql -h localhost -p 15432 -U postgres -c "SELECT 1;"` (password: password)
- [ ] Grafana LGTM: `curl -sf http://localhost:3000/api/health`
- [ ] OTLP endpoint: `curl -sf http://localhost:4318`

### 0.3 Verify Ollama
```bash
ollama list   # Should show qwen3, nomic-embed-text
curl http://localhost:11434/api/tags
```

### 0.4 Start provider-ollama (full profiles)
```bash
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation
```
- [ ] App starts without errors
- [ ] Actuator health: `curl http://localhost:8080/actuator/health`

---

## Phase 1: Stage 1 — Chat Fundamentals

Test each endpoint, record: response status, response content quality, latency, any errors.

### 1.1 chat_01 — Basic ChatModel
```bash
curl "http://localhost:8080/chat/01/joke?topic=spring"
```
- [ ] Returns 200 with joke text
- [ ] Note: response time, quality

### 1.2 chat_02 — ChatClient + ChatModel
```bash
curl "http://localhost:8080/chat/02/client/joke?topic=java"
curl "http://localhost:8080/chat/02/model/joke?topic=java"
```
- [ ] Both return jokes
- [ ] Compare ChatClient vs ChatModel response format

### 1.3 chat_03 — Prompt Templates
```bash
curl "http://localhost:8080/chat/03/joke?adjective=funny&topic=cats"
```
- [ ] Returns joke matching template variables

### 1.4 chat_04 — Structured Output
```bash
curl "http://localhost:8080/chat/04/plays/list"
curl "http://localhost:8080/chat/04/plays/map"
curl "http://localhost:8080/chat/04/plays/object"
```
- [ ] /list returns JSON array of strings
- [ ] /map returns JSON object
- [ ] /pojo returns typed Play[] JSON
- [ ] UI note: structured output is hard to see in raw curl — candidate for web UI viewer

### 1.5 chat_05 — Tool/Function Calling
```bash
curl "http://localhost:8080/chat/05/time?tz=Europe/Berlin"
curl "http://localhost:8080/chat/05/weather?city=Berlin"
curl "http://localhost:8080/chat/05/search?query=italian+restaurant+in+berlin"
```
- [ ] /time returns current time for timezone
- [ ] /weather returns weather data
- [ ] /search returns restaurant results
- [ ] qwen3 supports tool calling reliably

### 1.6 chat_06 — System Roles
```bash
curl "http://localhost:8080/chat/06/fruit"
curl "http://localhost:8080/chat/06/veg"
```
- [ ] /fruit responds as fruit expert
- [ ] /veg responds as vegetable expert

### 1.7 chat_07 — Multimodal (requires llava)
```bash
# Only works with llava model — may need to switch Ollama chat model
curl "http://localhost:8080/chat/07/explain"
```
- [ ] If llava available: returns image description
- [ ] If not: note the error for docs

### 1.8 chat_08 — Streaming
```bash
curl -N "http://localhost:8080/chat/08/essay?topic=spring"
```
- [ ] Returns streaming text (SSE/chunked)
- [ ] UI note: streaming is invisible in basic curl — needs web UI with live text rendering

### Stage 1 UI Notes
Record ideas for: web dashboard card layout, endpoint grouping, response formatting

---

## Phase 2: Stage 2 — Embeddings

### 2.1 embed_01 — Basic Embedding
```bash
curl "http://localhost:8080/embed/01/text?text=hello+world"
curl "http://localhost:8080/embed/01/dimension"
```
- [ ] /text returns float array
- [ ] /dimension returns 1024 (mxbai-embed-large)

### 2.2 embed_02 — Similarity
```bash
curl "http://localhost:8080/embed/02/words"
curl "http://localhost:8080/embed/02/quotes"
```
- [ ] /words returns similarity scores between word pairs
- [ ] /quotes returns ranked similar quotes
- [ ] UI note: similarity scores perfect for visualization (bar charts, heatmaps)

### 2.3 embed_03 — Large Documents
```bash
curl "http://localhost:8080/embed/03/big"
curl "http://localhost:8080/embed/03/chunk"
```
- [ ] /big embeds Shakespeare — may be slow
- [ ] /chunk shows chunking + embedding
- [ ] Note chunk count and processing time

### 2.4 embed_04 — Document Readers
```bash
curl "http://localhost:8080/embed/04/json/bikes"
curl "http://localhost:8080/embed/04/text/works"
curl "http://localhost:8080/embed/04/pdf/pages"
curl "http://localhost:8080/embed/04/pdf/para"
```
- [ ] All four document types read and embed successfully
- [ ] Note document counts per reader type

---

## Phase 3: Stage 3 — Vector Stores

### 3.1 vector_01 — Load & Query (with pgvector)
```bash
curl "http://localhost:8080/vector/01/load"
curl "http://localhost:8080/vector/01/query?topic=mountain"
```
- [ ] /load populates pgvector
- [ ] /query returns relevant bike documents
- [ ] Verify in pgAdmin (http://localhost:15433) that vectors are stored
- [ ] UI note: vector search results need document preview + relevance score display

---

## Phase 4: Stage 4 — AI Patterns

### 4.1 Stuff the Prompt
```bash
curl "http://localhost:8080/stuffit/01/query?topic=bikes"
```
- [ ] Returns answer with bike context

### 4.2 RAG
```bash
curl "http://localhost:8080/rag/01/load"
curl "http://localhost:8080/rag/01/query?topic=mountain+bike"
curl "http://localhost:8080/rag/02/load"
curl "http://localhost:8080/rag/02/query?topic=commuter+bike"
```
- [ ] Load succeeds for both RAG approaches
- [ ] Queries return bike-specific answers
- [ ] Compare quality: manual RAG vs QuestionAnswerAdvisor

### 4.3 Chat Memory
```bash
curl "http://localhost:8080/mem/02/hello?message=Hi+my+name+is+Alice"
curl "http://localhost:8080/mem/02/name"
```
- [ ] First call introduces Alice
- [ ] Second call correctly recalls "Alice"
- [ ] UI note: chat memory is a perfect candidate for a chat-style web UI

---

## Phase 5: Stage 5 — Advanced Agents

### 5.1 Chain of Thought
```bash
curl "http://localhost:8080/cot/bio/oneshot"
curl "http://localhost:8080/cot/bio/flow"
```
- [ ] /oneshot returns basic bio
- [ ] /flow returns multi-step bio (better quality)
- [ ] Note: these may be slow (multiple LLM calls)
- [ ] UI note: show intermediate steps (outline, draft, refinements) in accordion/tabs

### 5.2 Self-Reflection
```bash
curl "http://localhost:8080/reflection/bio/oneshot"
curl "http://localhost:8080/reflection/bio/agent?iterations=3"
```
- [ ] /oneshot returns baseline bio
- [ ] /agent returns iteratively improved bio
- [ ] UI note: show writer/critic iterations side by side

---

## Phase 6: Stage 6 — MCP (Model Context Protocol)

MCP modules run as separate Spring Boot apps, not part of provider-ollama.

### 6.1 MCP 01 — Stdio Server
```bash
./mvnw spring-boot:run -pl mcp/01-basic-stdio-mcp-server
```
- [ ] Starts and communicates via stdin/stdout
- [ ] Test with the ClientStdio test class

### 6.2 MCP 02 — HTTP Server (Streamable HTTP)
```bash
./mvnw spring-boot:run -pl mcp/02-basic-http-mcp-server
# In another terminal, run the test client
```
- [ ] Server starts on port 8080
- [ ] Client connects via Streamable HTTP transport
- [ ] Tools are listed and callable

### 6.3 MCP 05 — Full Capabilities
```bash
./mvnw spring-boot:run -pl mcp/05-mcp-capabilities
```
- [ ] Server starts
- [ ] Tools, resources, prompts, completions all accessible
- [ ] Verify annotation-based MCP registration works after migration

---

## Phase 7: Stage 7 — Agentic Systems

These require provider-openai running (agents use OpenAI-specific options). 
For Ollama-only testing, we can test if the apps start but full agent interaction needs OpenAI.

### 7.1 Inner Monologue Agent (app)
```bash
./mvnw spring-boot:run -pl agentic-system/01-inner-monologue/inner-monologue-agent
```
- [ ] App starts without errors
- [ ] Note: full testing requires OpenAI API key

### 7.2 Model-Directed Loop Agent (app)
```bash
./mvnw spring-boot:run -pl agentic-system/02-model-directed-loop/model-directed-loop-agent
```
- [ ] App starts without errors

### 7.3 CLI Modules
```bash
./mvnw spring-boot:run -pl agentic-system/01-inner-monologue/inner-monologue-cli
./mvnw spring-boot:run -pl agentic-system/02-model-directed-loop/model-directed-loop-cli
```
- [ ] Shell starts (verify Spring Shell 4 migration works)
- [ ] Commands are registered and listed

---

## Phase 8: Stage 8 — Observability Validation

### 8.1 Verify traces in Grafana
With provider-ollama running with `observation` profile:
```bash
curl "http://localhost:8080/chat/01/joke?topic=spring"
curl "http://localhost:8080/rag/01/load"
curl "http://localhost:8080/rag/01/query?topic=mountain"
```
Then in Grafana (http://localhost:3000):
- [ ] Explore → Tempo → Find traces for spring-ai-workshop service
- [ ] Verify spans show controller → service hierarchy
- [ ] Check trace IDs appear in span attributes

### 8.2 Verify metrics
- [ ] Explore → Mimir → Query `http_server_requests_seconds_count`
- [ ] Check JVM Micrometer dashboard loads with data
- [ ] Check HikariCP/JDBC dashboard (if pgvector profile active)

### 8.3 Verify logs
- [ ] Explore → Loki → Query `{service_name="ollama-provider"}`
- [ ] Verify logs contain trace IDs for correlation
- [ ] Click trace ID in log → should jump to Tempo trace view

### 8.4 Dashboard compatibility
- [ ] Workshop folder visible in Grafana sidebar
- [ ] JVM Micrometer dashboard shows panels with data
- [ ] Spring Boot Microservices dashboard shows panels with data
- [ ] HikariCP/JDBC dashboard shows connection pool metrics
- [ ] Note any datasource UID mismatches → fix in JSON files

---

## Phase 9: UI Improvement Evaluation

After testing all stages, compile findings into three UI tracks:

### 9a: Web Dashboard Plan
Based on test findings, design a web dashboard that:
- Lists all workshop stages as cards/sections
- Each stage shows its endpoints with one-click "Try it" buttons
- Displays responses in formatted views (JSON pretty-print, streaming text, similarity charts)
- Chat memory gets a chat-style interface
- Agent patterns show intermediate steps (CoT outline, reflection iterations)
- Embedding similarity gets visual comparison (bar charts / dot plots)
- Technology: Thymeleaf templates or static HTML+JS (htmx for interactivity)

### 9b: Swagger/OpenAPI Plan
- Add SpringDoc OpenAPI to all provider apps
- Group endpoints by stage (chat, embedding, vector, patterns, etc.)
- Add request/response examples to each endpoint
- Add model schemas for structured output types
- Enable "Try it out" for interactive testing

### 9c: CLI Enhancement Plan
- Fix Spring Shell 4 custom prompt (currently removed)
- Add progress indicators for long-running AI calls
- Add colored output for agent reasoning steps
- Consider adding shell commands for demo setup (load data, etc.)

### 9d: Cross-cutting UI Notes
Capture during testing:
- Which endpoints return raw text vs JSON vs streaming
- Which demos need setup steps (load data first)
- Which demos are slow and need loading indicators
- Which demos produce rich output that benefits from formatting

---

## Phase 10: Provider Integration Test (Extra Topic)

Separate from the main flow — test provider compatibility matrix.

### 10.1 Provider Startup Matrix — Results (verified 2026-04-03)

| Provider | Starts? | Chat works? | Embeddings? | Tools? | Notes |
|----------|---------|-------------|-------------|--------|-------|
| Ollama | Yes | 14/14 PASS | 10/10 PASS | Yes | Primary, all 44/44 pass |
| OpenAI | Yes | 14/14 PASS | 10/10 PASS | Yes | All 44/44 pass |
| Anthropic | Yes | 14/14 PASS | N/A | Yes | No embedding API; spy profile fix applied |
| Azure | PASS | PASS | N/A | N/A | 8/8 chat pass with gpt-4.1-mini (East US) |
| Google | PASS | PASS | N/A | N/A | 13/13 chat pass with gemini-2.5-flash |
| AWS | Yes | 7/7 PASS | N/A | Yes | Amazon Nova Lite, eu-central-1; 8/8 total |

### 10.2 Gateway Test
```bash
# Shut down local Spring MCP server first (port 7777 conflict)
./mvnw spring-boot:run -pl applications/gateway
```
- [ ] Gateway starts on port 7777
- [ ] Test spy profile with Ollama: routes /ollama/** to localhost:11434
- [ ] Verify request/response logging in gateway console

### 10.3 Provider-Specific Features — Results (verified 2026-04-03)
- [x] OpenAI: all 44/44 endpoints pass
- [x] Anthropic: 14/14 chat endpoints pass (structured output, tool calling, streaming). No embeddings (Anthropic doesn't offer them). Fixed spy profile hardcoded active.
- [x] AWS Bedrock: 8/8 pass (7 chat + 1 stuff-the-prompt). Amazon Nova Lite works instantly; Anthropic models require use case form. Converse starter doesn't auto-configure EmbeddingModel.
- [x] Google: 13/13 PASS with gemini-2.5-flash (dependency conflicts fixed with okhttp/protobuf overrides)
- [x] Azure OpenAI: 8/8 PASS with gpt-4.1-mini (Standard SKU, East US)

---

## Execution Approach

Execute phases **sequentially** (0 through 10). For each phase:
1. Run the commands
2. Record pass/fail for each checkbox
3. Capture response samples and latency
4. Note UI improvement ideas in context
5. Update `migration/test_results.md` with findings

After all phases, produce:
- `migration/test_results.md` — detailed test results per endpoint
- `migration/ui_improvement_plan.md` — web dashboard + Swagger + CLI plan with mockups
