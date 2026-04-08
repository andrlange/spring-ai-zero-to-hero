# Model Mapping — Stage / Demo / Capability / Provider Matrix

Maps every workshop demo to its required AI capabilities and which providers support it.

---

## Ollama Model Requirements

| Model | Size | RAM | Context | Dims | Purpose |
|-------|------|-----|---------|------|---------|
| `qwen3` | 5.2 GB | ~8 GB | 32k | - | Chat (default) — structured output + tool calling |
| `nomic-embed-text` | 274 MB | ~1 GB | 8192 | 768 | Embeddings (default) |
| `llava` | 4.7 GB | ~8 GB | 4096 | - | Multimodal (auto-switched for chat_07) |
| `llama3.2` | 2.0 GB | ~4 GB | 128k | - | Optional: fast chat for simple demos |

**16 GB macOS:** Run `qwen3` + `nomic-embed-text` simultaneously (~10 GB). `llava` loads on-demand for chat_07 only.

---

## Stage 1: Chat Fundamentals

| Demo | Endpoint | Capability | Ollama (qwen3) | OpenAI (gpt-4o-mini) | Anthropic (Claude) | Notes |
|------|----------|------------|:-:|:-:|:-:|-------|
| chat_01 | `/chat/01/joke` | Basic chat | PASS | PASS | PASS | |
| chat_02 client | `/chat/02/client/joke` | ChatClient API | PASS | PASS | PASS | |
| chat_02 model | `/chat/02/model/joke` | ChatModel API | PASS | PASS | PASS | |
| chat_03 | `/chat/03/joke` | Prompt templates | PASS | PASS | PASS | |
| chat_04 list | `/chat/04/plays/list` | Structured -> List | PASS | PASS | PASS | |
| chat_04 map | `/chat/04/plays/map` | Structured -> Map | PASS | PASS | PASS | Prompt tuned for map structure |
| chat_04 object | `/chat/04/plays/object` | Structured -> POJO | PASS | PASS | PASS | Requires qwen3 8B for Ollama |
| chat_05 time | `/chat/05/time` | Tool calling | PASS | PASS | PASS | |
| chat_05 weather | `/chat/05/weather` | Tool calling (named) | PASS | PASS | PASS | `weatherFunction` bean auto-discovered |
| chat_05 search | `/chat/05/search` | Tools + returnDirect | PASS | PASS | PASS | Fixed: String params, manual JSON parse |
| chat_06 fruit | `/chat/06/fruit` | System roles | PASS | PASS | PASS | |
| chat_06 veg | `/chat/06/veg` | System roles | PASS | PASS | PASS | |
| chat_07 | `/chat/07/explain` | Multimodal | PASS | PASS | PASS (3+) | Auto-switches to llava for Ollama |
| chat_08 | `/chat/08/essay` | Streaming | PASS | PASS | PASS | |

### Stage 1 Summary
- **Ollama (qwen3): 14/14 PASS**
- **OpenAI (gpt-4o-mini): 14/14 PASS**

---

## Stage 2: Embeddings

| Demo | Endpoint | Capability | Ollama (nomic-embed-text) | OpenAI (text-embedding-3) | Notes |
|------|----------|------------|:-:|:-:|-------|
| embed_01 text | `/embed/01/text` | Single text embedding | PASS (768d) | PASS (1536d) | |
| embed_01 dim | `/embed/01/dimension` | Model dimensions | PASS | PASS | |
| embed_02 words | `/embed/02/words` | Cosine similarity | PASS | PASS | |
| embed_02 quotes | `/embed/02/quotes` | Semantic search | PASS | PASS | |
| embed_03 big | `/embed/03/big` | Large document | PASS* | PASS* | *Returns 200 with graceful error (doc too large) |
| embed_03 chunk | `/embed/03/chunk` | TokenTextSplitter | PASS | PASS | 1847 chunks, 3 embedded |
| embed_04 json | `/embed/04/json/bikes` | JSON reader | PASS | PASS | 25 bike docs |
| embed_04 text | `/embed/04/text/works` | Text reader | PASS | PASS | Chunked + embedded |
| embed_04 pdf | `/embed/04/pdf/pages` | PDF page reader | PASS | PASS | 18 pages from bylaw.pdf |
| embed_04 pdf | `/embed/04/pdf/para` | PDF paragraph reader | PASS | PASS | 5 paragraphs |

### Stage 2 Summary
- **Ollama: 10/10 PASS**
- **OpenAI: 10/10 PASS**
- Note: correct PDF paths are `/pdf/pages` and `/pdf/para` (not `/page` or `/paragraph`)

---

## Stage 3: Vector Stores

| Demo | Endpoint | Capability | Ollama | OpenAI | Notes |
|------|----------|------------|:-:|:-:|-------|
| vector_01 load | `/vector/01/load` | Batch load + embed | PASS | PASS | TokenTextSplitter chunking applied |
| vector_01 query | `/vector/01/query` | Similarity search | PASS | PASS | Returns relevant bike docs |

### Stage 3 Summary
- **Both providers: 2/2 PASS**
- Requires `pgvector` profile for persistent storage

---

## Stage 4: AI Patterns

| Demo | Endpoint | Capability | Ollama | OpenAI | Notes |
|------|----------|------------|:-:|:-:|-------|
| stuffit_01 | `/stuffit/01/query` | Prompt stuffing | PASS | PASS | ~5s Ollama, ~2s OpenAI |
| rag_01 load | `/rag/01/load` | RAG data loading | PASS | PASS | 72 chunks from 25 docs |
| rag_01 query | `/rag/01/query` | Manual RAG | PASS | PASS | |
| rag_02 load | `/rag/02/load` | Advisor RAG loading | PASS | PASS | |
| rag_02 query | `/rag/02/query` | QuestionAnswerAdvisor | PASS | PASS | |
| mem_02 hello | `/mem/02/hello` | Chat memory (send) | PASS | PASS | |
| mem_02 name | `/mem/02/name` | Chat memory (recall) | PASS | PASS | Correctly recalls name |

### Stage 4 Summary
- **Both providers: 7/7 PASS**
- RAG requires `pgvector` profile and prior `/load` call

---

## Stage 5: Advanced Agent Patterns

| Demo | Endpoint | Capability | Ollama | OpenAI | Notes |
|------|----------|------------|:-:|:-:|-------|
| cot oneshot | `/cot/bio/oneshot` | Single-pass generation | PASS | PASS | |
| cot flow | `/cot/bio/flow` | Multi-step CoT | PASS | PASS | ~10s Ollama (multiple LLM calls) |
| reflection oneshot | `/reflection/bio/oneshot` | Single-pass baseline | PASS | PASS | |
| reflection agent | `/reflection/bio/agent` | Writer+Critic loop | PASS | PASS | ~6s for 2 iterations |

### Stage 5 Summary
- **Both providers: 4/4 PASS**
- Requires `Profile.pdf` in classpath (included in repo)

---

## Stage 6: MCP (Model Context Protocol)

| Demo | Module | Transport | Status | Notes |
|------|--------|-----------|:-:|-------|
| 01 | basic-stdio-mcp-server | STDIO | PASS | Standalone, no AI model needed |
| 02 | basic-http-mcp-server | Streamable HTTP | PASS | 1 tool, resources, prompts registered |
| 03 | basic-mcp-client | STDIO | PASS* | *Client configured for OpenAI |
| 04 server | dynamic-tool-calling/server | Streamable HTTP | PASS | Standalone |
| 04 client | dynamic-tool-calling/client | HTTP | PASS* | *Client configured for OpenAI |
| 05 | mcp-capabilities | Streamable HTTP | PASS | 2 tools, 9 templates, 12 prompts, 6 completions |

### Stage 6 Summary
- **6/6 PASS** (servers provider-independent, clients use OpenAI)
- Each module runs as separate Spring Boot app

---

## Stage 7: Agentic Systems

| Demo | Module | Status | Notes |
|------|--------|:-:|-------|
| inner-monologue agent | 01 agent | PASS* | *Requires OpenAI (uses `OpenAiChatOptions`) |
| inner-monologue CLI | 01 cli | PASS | Spring Shell 4, commands registered |
| model-directed-loop agent | 02 agent | PASS* | *Requires OpenAI |
| model-directed-loop CLI | 02 cli | PASS | Spring Shell 4, commands registered |

### Stage 7 Summary
- **4/4 PASS** (agent apps need OpenAI, CLIs are provider-independent)
- Could migrate to `ToolCallingChatOptions` for provider-agnostic support

---

## Stage 8: Observability

| Feature | Capability | Status | Notes |
|---------|------------|:-:|-------|
| Distributed tracing | OTLP -> Tempo | PASS | service_name visible in Grafana |
| Metrics | OTLP -> Mimir | PASS | HikariCP, HTTP metrics flowing |
| Logs | Logback -> OTLP -> Loki | PASS | logback-spring.xml with OTel appender |
| Custom tracing | @TracedEndpoint/Service/Repository | AVAILABLE | Module wired in, annotations ready to use |
| Dashboards | Grafana provisioned | PASS | JVM, HikariCP, Spring Boot dashboards |

### Stage 8 Summary
- **All telemetry signals PASS** — traces, metrics, logs flow to LGTM
- Requires `observation` profile
- Micrometer 1.16 metric names changed (`_seconds` -> `_milliseconds`)

---

## Provider Compatibility Matrix (Summary)

Verified 2026-04-03 for all providers.

| Stage | Endpoints | Ollama (qwen3 + nomic) | OpenAI (gpt-4o-mini) | Anthropic (Claude) | AWS Bedrock (Nova Lite) | Google (Gemini 2.5 Flash) | Azure OpenAI (gpt-4.1-mini) |
|-------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 1. Chat | 14 | **14 PASS** | **14 PASS** | **14 PASS** | **7 PASS** | **13 PASS** | **7 PASS** |
| 2. Embeddings | 10 | **10 PASS** | **10 PASS** | N/A (no embeddings) | N/A (chat-only starter) | **13 PASS** | **7 PASS** |
| 3. Vector Stores | 2 | **2 PASS** | **2 PASS** | N/A | N/A | **13 PASS** | **7 PASS** |
| 4. Patterns | 7 | **7 PASS** | **7 PASS** | N/A | **1 PASS** (stuffit) | **13 PASS** | **7 PASS** |
| 5. Agents | 4 | **4 PASS** | **4 PASS** | N/A | N/A | **13 PASS** | **7 PASS** |
| 6. MCP | 6 | **6 PASS** | **6 PASS** | N/A | N/A | **13 PASS** | **7 PASS** |
| 7. Agentic | 4 | 2 PASS (CLIs) | **4 PASS** | N/A | N/A | **13 PASS** | **7 PASS** |
| 8. Observability | 5 | **5 PASS** | **5 PASS** | N/A | N/A | **13 PASS** | **7 PASS** |
| **Total** | **52** | **50/52** | **52/52** | **14/14** | **8/8** | **13/13** | **8/8** |

**Notes:**
- **Anthropic**: All 14 chat endpoints pass (structured output, tool calling, streaming). No embedding API available.
- **AWS Bedrock**: Amazon Nova Lite in eu-central-1. Anthropic models require use case form. Converse starter is chat-only (no EmbeddingModel auto-config).
- **Google**: 13/13 PASS with gemini-2.5-flash. Requires okhttp/protobuf overrides in pom.xml. Embedding module excluded (needs separate API key config).
- **Azure OpenAI**: 8/8 PASS with gpt-4.1-mini in East US. Standard SKU required (not GlobalStandard). Deprecated functions config removed.

---

## Recommended Demo Flow by Provider

### Ollama (Workshop / Offline Mode) — 50/52
Best path: All stages 1-8 work. Only agentic agent apps (Stage 7) need OpenAI.
```bash
ollama pull qwen3 && ollama pull nomic-embed-text && ollama pull llava
./mvnw spring-boot:run -pl applications/provider-ollama -Dspring-boot.run.profiles=pgvector,observation
```

### OpenAI (Full Feature Mode) — 52/52
Best path: All stages 1-8, all demos work.
```bash
./mvnw spring-boot:run -pl applications/provider-openai -Dspring-boot.run.profiles=pgvector,observation
```

### Anthropic (Chat-Only Mode) — 14/14
Best path: Stage 1 (all 14 chat endpoints pass). No embeddings, vectors, RAG, or agents tested (no embedding API).
```bash
./mvnw spring-boot:run -pl applications/provider-anthropic -Dspring-boot.run.profiles=observation
```

### AWS Bedrock (Amazon Nova Lite) — 8/8
Best path: Stage 1 chat (7 endpoints) + Stage 4 stuff-the-prompt (1 endpoint). Region: eu-central-1.
```bash
./mvnw spring-boot:run -pl applications/provider-aws -Dspring-boot.run.profiles=observation
```
