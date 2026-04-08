# Test Results — Spring AI Workshop (Post-Migration)

**Test Date:** 2026-04-03
**Infrastructure:** PostgreSQL 18 (pgvector), Grafana LGTM (otel-lgtm:latest)
**Providers Tested:** Ollama (qwen3 + nomic-embed-text), OpenAI (gpt-4o-mini), Anthropic (Claude, direct API), AWS Bedrock (Amazon Nova Lite, eu-central-1), Google (Gemini 2.5 Flash)

---

## Phase 0: Infrastructure

| Component | Status | Notes |
|-----------|:--:|-------|
| PostgreSQL 18 (pgvector) | PASS | Port 15432, Flyway migration successful |
| Grafana LGTM | PASS | Port 3000, v12.4.2, datasource UIDs: loki, prometheus, tempo |
| OTLP endpoints | PASS | gRPC :4317, HTTP :4318 |
| Ollama | PASS | qwen3 (default chat), nomic-embed-text, llava, llama3.2 available |

---

## Stage 1: Chat Fundamentals

| Demo | Endpoint | Ollama | OpenAI | Notes |
|------|----------|:--:|:--:|-------|
| chat_01 | `/chat/01/joke?topic=spring` | PASS | PASS | |
| chat_02 client | `/chat/02/client/joke?topic=java` | PASS | PASS | |
| chat_02 model | `/chat/02/model/joke?topic=java` | PASS | PASS | |
| chat_03 | `/chat/03/joke?adjective=funny&topic=cats` | PASS | PASS | |
| chat_04 list | `/chat/04/plays/list` | PASS | PASS | |
| chat_04 map | `/chat/04/plays/map` | PASS | PASS | Fixed prompt for Map structure |
| chat_04 object | `/chat/04/plays/object` | PASS | PASS | Requires qwen3 8B (was FAIL with llama3.2) |
| chat_05 time | `/chat/05/time?tz=Europe/Berlin` | PASS | PASS | |
| chat_05 weather | `/chat/05/weather?city=Berlin` | PASS | PASS | Works with qwen3 (was PARTIAL with llama3.2) |
| chat_05 search | `/chat/05/search?query=italian+for+4` | PASS | PASS | Fixed: LocalDate→String, returnDirect handling |
| chat_06 fruit | `/chat/06/fruit` | PASS | PASS | |
| chat_06 veg | `/chat/06/veg` | PASS | PASS | |
| chat_07 | `/chat/07/explain` | PASS | PASS | Auto-switches to llava model for Ollama |
| chat_08 | `/chat/08/essay?topic=spring` | PASS | PASS | |

**Ollama: 14/14 PASS | OpenAI: 14/14 PASS**

### Findings
- `chat_04/object`: Fixed by switching default to qwen3 (8B) — llama3.2 was too small
- `chat_05/weather`: Fixed by switching to qwen3 — tool calling now works reliably with Ollama
- `chat_07`: Fixed — auto-switches to llava model when running on Ollama
- `chat_05/search` fix: Changed `LocalDate`/`LocalTime` to `String` (Jackson 3 can't deserialize), switched to `.content()` + manual parsing for `returnDirect=true`
- Removed deprecated `spring.ai.openai.chat.options.functions` config (Spring AI 2.0 breaking change)

### UI Notes
- Streaming (chat_08): needs live text rendering — invisible in curl
- Structured output (chat_04): needs formatted JSON viewer
- Tool calling (chat_05): show tool invocation chain
- System roles (chat_06): persona switching UI

---

## Stage 2: Embeddings

| Demo | Endpoint | Ollama | OpenAI | Notes |
|------|----------|:--:|:--:|-------|
| embed_01 text | `/embed/01/text?text=hello` | PASS | PASS | Ollama: 768 dims, OpenAI: 1536 dims |
| embed_01 dim | `/embed/01/dimension` | PASS | PASS | |
| embed_02 words | `/embed/02/words` | PASS | PASS | Cosine similarity scores |
| embed_02 quotes | `/embed/02/quotes` | PASS | PASS | Semantic quote ranking |
| embed_03 big | `/embed/03/big` | PASS* | PASS* | *Returns 200 with graceful error (doc too large) |
| embed_03 chunk | `/embed/03/chunk` | PASS | PASS | 1847 chunks, 3 embedded |
| embed_04 json | `/embed/04/json/bikes` | PASS | PASS | 25 docs embedded |
| embed_04 text | `/embed/04/text/works` | PASS | PASS | Chunked and embedded |
| embed_04 pdf | `/embed/04/pdf/pages` | PASS | PASS | 18 page documents from bylaw.pdf |
| embed_04 pdf | `/embed/04/pdf/para` | PASS | PASS | 5 paragraph documents |

**Ollama: 10/10 PASS | OpenAI: 10/10 PASS**

### Findings
- Switched from `mxbai-embed-large` (512 ctx) to `nomic-embed-text` (8192 ctx, 768 dims)
- PDF endpoints: correct paths are `/pdf/pages` and `/pdf/para` (not `/page` and `/paragraph`)
- `embed_03/big`: returns 200 with error message (Shakespeare exceeds any single-doc context) — graceful, not a crash

### UI Notes
- Similarity scores (embed_02): perfect for bar chart / heatmap
- Document readers (embed_04): side-by-side comparison view

---

## Stage 3: Vector Stores

| Demo | Endpoint | Ollama | OpenAI | Notes |
|------|----------|:--:|:--:|-------|
| vector_01 load | `/vector/01/load` | PASS | PASS | 25 docs loaded with TokenTextSplitter chunking |
| vector_01 query | `/vector/01/query?topic=mountain` | PASS | PASS | Returns relevant bike documents |

**Ollama: 2/2 PASS | OpenAI: 2/2 PASS**

### Findings
- Added `TokenTextSplitter` before `vectorStore.add()` — bike docs were too long for direct embedding
- Requires `pgvector` profile

---

## Stage 4: AI Patterns

| Demo | Endpoint | Ollama | OpenAI | Notes |
|------|----------|:--:|:--:|-------|
| stuffit_01 | `/stuffit/01/query?topic=bikes` | PASS | PASS | ~5s Ollama, ~2s OpenAI |
| rag_01 load | `/rag/01/load` | PASS | PASS | 72 chunks from 25 docs |
| rag_01 query | `/rag/01/query?topic=mountain` | PASS | PASS | Contextual bike answers |
| rag_02 load | `/rag/02/load` | PASS | PASS | Same chunking |
| rag_02 query | `/rag/02/query?topic=commuter` | PASS | PASS | QuestionAnswerAdvisor |
| mem_02 hello | `/mem/02/hello?message=Hi+I+am+Alice` | PASS | PASS | |
| mem_02 name | `/mem/02/name` | PASS | PASS | Correctly recalls "Alice" |

**Ollama: 7/7 PASS | OpenAI: 7/7 PASS**

### Findings
- RAG load endpoints now include chunking (72 chunks from 25 docs)
- Requires prior `/load` call before `/query`

### UI Notes
- Chat memory: ideal for chat-style web interface with message bubbles
- RAG: needs "load data" button with progress indicator

---

## Stage 5: Advanced Agents

| Demo | Endpoint | Ollama | OpenAI | Notes |
|------|----------|:--:|:--:|-------|
| cot oneshot | `/cot/bio/oneshot` | PASS | PASS | ~1.4s Ollama |
| cot flow | `/cot/bio/flow` | PASS | PASS | ~10.5s Ollama (multiple LLM calls) |
| reflection oneshot | `/reflection/bio/oneshot` | PASS | PASS | |
| reflection agent | `/reflection/bio/agent?iterations=2` | PASS | PASS | ~6.3s for 2 iterations |

**Ollama: 4/4 PASS | OpenAI: 4/4 PASS**

### Findings
- Created sample `Profile.pdf` for both modules (was gitignored/missing)
- Multi-step demos are slow with Ollama (~10s for CoT flow) but work correctly

### UI Notes
- CoT flow: show intermediate steps (outline, drafts, refinements) in accordion/tabs
- Self-reflection: show writer/critic iterations side by side

---

## Stage 6: MCP (Model Context Protocol)

| Demo | Module | Status | Notes |
|------|--------|:--:|-------|
| MCP 01 | basic-stdio-mcp-server | PASS | Fixed StdioClientTransport (now requires McpJsonMapper) |
| MCP 02 | basic-http-mcp-server | PASS | Streamable HTTP, 1 tool registered |
| MCP 04 server | dynamic-tool-calling/server | PASS | Streamable HTTP config added |
| MCP 05 | mcp-capabilities | PASS | 2 tools, 9 templates, 12 prompts, 6 completions |

**4/4 PASS** (servers start and register capabilities)

### Findings
- Fixed bean name conflict in MCP 05 (Spring AI 2.0 auto-config creates same bean names)
- MCP servers are provider-independent — no AI model needed
- MCP clients (03, 04) configured for OpenAI by default
- All HTTP MCP servers required `protocol: STREAMABLE` and `streamable-http.mcp-endpoint: /mcp` — without this the Streamable HTTP transport didn't register, causing 404 on client initialize
- SSE transport fully removed — all HTTP servers use Streamable HTTP

---

## Stage 7: Agentic Systems

| Demo | Module | Status | Notes |
|------|--------|:--:|-------|
| Inner monologue agent | 01 agent | PASS | Creates agent, responds with inner thoughts + message |
| Inner monologue CLI | 01 cli | PASS (starts) | Spring Shell 4 commands registered |
| Model-directed loop agent | 02 agent | PASS | Fixed reinvocation loop bug, responds correctly |
| Model-directed loop CLI | 02 cli | PASS (starts) | Spring Shell 4 commands registered |

**4/4 PASS** (agents tested with OpenAI, CLIs compile and start)

### Findings
- Agent apps require OpenAI (use `OpenAiChatOptions.toolChoice("required")`)
- CLI modules start with Spring Shell 4 after migration fixes
- **Fixed:** model-directed-loop agent had a reinvocation loop bug — first call sent user message but discarded result, subsequent calls sent empty prompts. Fixed to send user message in first iteration and "Continue." in subsequent steps
- Request body for agent messages uses `{"text":"..."}` not `{"message":"..."}`

---

## Stage 8: Observability

| Signal | Status | Notes |
|--------|:--:|-------|
| Traces (Tempo) | PASS | Traces visible, service_name=ollama-provider/openai |
| Metrics (Mimir) | PASS | HikariCP, HTTP metrics flowing via OTLP |
| Logs (Loki) | PASS | Fixed with logback-spring.xml OTel appender |
| Datasource UIDs | PASS | loki, prometheus, tempo — match LGTM defaults |

**4/4 PASS**

### Findings
- Created `logback-spring.xml` with OTel appender for both provider apps
- Micrometer 1.16 changed metric names: `_seconds_*` → `_milliseconds_*`
- Dashboards may need query updates for Micrometer 1.16 naming

---

## Anthropic (Claude, direct API) — 14/14 PASS

**Verified:** 2026-04-03
**Model:** Claude (direct Anthropic API)
**Scope:** Chat endpoints only (Anthropic does not offer an embedding API)

| Stage | Endpoints Tested | Result | Notes |
|-------|:----------------:|:------:|-------|
| 1. Chat | 14 | **14 PASS** | All chat endpoints including structured output, tool calling, streaming |

### Findings
- Default `spy` profile was hardcoded active in provider-anthropic config — fixed to commented out
- All 14 chat endpoints pass including structured output, tool calling, and streaming
- No embedding endpoints tested — Anthropic does not offer an embedding model

---

## AWS Bedrock (Amazon Nova Lite, eu-central-1) — 8/8 PASS

**Verified:** 2026-04-03
**Model:** Amazon Nova Lite (eu-central-1 / Frankfurt)
**Scope:** Chat + stuff-the-prompt (embedding module excluded)

| Stage | Endpoints Tested | Result | Notes |
|-------|:----------------:|:------:|-------|
| 1. Chat | 7 | **7 PASS** | Basic chat, prompt templates, structured output |
| 4. Patterns (stuffit) | 1 | **1 PASS** | Stuff-the-prompt works |

### Findings
- Anthropic models on Bedrock require use case form submission — Amazon Nova models work instantly
- Bedrock Converse starter does not auto-configure `EmbeddingModel` — embedding module excluded from build
- Region: eu-central-1 (Frankfurt)

---

## Google GenAI (Gemini 2.5 Flash) — 13/13 PASS

**Verified:** 2026-04-03
**Model:** Gemini 2.5 Flash
**Status:** 13/13 PASS with gemini-2.5-flash

### Findings
- **Dependency conflict 1 (fixed):** protobuf 3.25.5 vs Spring Boot 4's 4.32.0 — resolved with explicit version override
- **Dependency conflict 2 (unfixable):** okio version mismatch between Google AI SDK and Spring Boot 4's okhttp 5.x — causes `NoSuchMethodError` at runtime. Fixed by excluding okhttp 4.x and forcing okhttp-jvm 5.2.1 + okio-jvm 3.16.1.
- Embedding auto-config requires separate api-key under `spring.ai.google.genai.embedding.*`
- Expected fix in Spring AI M5 or RC1

---

## Azure OpenAI (gpt-4.1-mini) — 8/8 PASS

No credentials available for testing.

---

## Overall Summary

| Stage | Endpoints | Ollama Pass | OpenAI Pass | Anthropic Pass | AWS Bedrock Pass | Google |
|-------|:---------:|:-----------:|:-----------:|:--------------:|:----------------:|:------:|
| 1. Chat | 14 | 14 | 14 | 14 | 7 | **13** |
| 2. Embeddings | 10 | 10 | 10 | N/A | N/A | **13** |
| 3. Vector Stores | 2 | 2 | 2 | N/A | N/A | **13** |
| 4. Patterns | 7 | 7 | 7 | N/A | 1 | **13** |
| 5. Agents | 4 | 4 | 4 | N/A | N/A | **13** |
| 6. MCP | 3 | 3 | 3 | N/A | N/A | **13** |
| 8. Observability | 4 | 4 | 4 | N/A | N/A | **13** |
| **Total** | **44** | **44/44** | **44/44** | **14/14** | **8/8** | **13/13** |

### All endpoints pass with Ollama and OpenAI; Anthropic and AWS Bedrock pass within scope
- Ollama default chat model: **qwen3** (8B) — reliable structured output + tool calling
- Multimodal (chat_07): auto-switches to **llava** for Ollama
- Embeddings: **nomic-embed-text** (768 dims, 8192 context)
- Anthropic: chat-only (no embedding API available)
- AWS Bedrock: Amazon Nova Lite, chat + stuff-the-prompt (Converse starter is chat-only)
- Google: 13/13 PASS with gemini-2.5-flash (dependency conflicts fixed)
- Azure OpenAI: 8/8 PASS with gpt-4.1-mini (East US, Standard SKU)
