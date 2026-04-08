# Demo Flow — Spring AI Zero-to-Hero Workshop

A complete walkthrough of the workshop structure, demo flow, and AI provider options.

**Tech Stack:** Spring Boot 4.0.5 | Spring AI 2.0.0-M4 | Java 25 | Spring Framework 7

---

## Project Architecture

```
spring-ai-zero-to-hero/
|
+-- workshop.sh                 <-- Unified CLI: check, setup, start, stop, reset, status
|
+-- applications/               <-- Provider-specific Spring Boot apps (pick one to run)
|   +-- provider-ollama/        <-- LOCAL: No API keys, runs on your machine
|   +-- provider-openai/        <-- CLOUD: Full features (chat, image, audio, multimodal)
|   +-- provider-anthropic/     <-- CLOUD: Claude models
|   +-- provider-azure/         <-- ENTERPRISE: Azure OpenAI + Azure Vector Store
|   +-- provider-google/        <-- CLOUD: Gemini models
|   +-- provider-aws/           <-- ENTERPRISE: Bedrock (Claude, Titan)
|   +-- gateway/                <-- Network spy for inspecting API calls
|
+-- components/                 <-- Shared modules (provider-independent)
|   +-- apis/                   <-- API demos: chat, embedding, vector-store, audio, image
|   +-- patterns/               <-- AI patterns: RAG, chat memory, stuff-prompt, CoT, reflection, tracing
|   +-- config-openapi/         <-- OpenAPI/Swagger UI (always active)
|   +-- config-dashboard/       <-- Workshop dashboard UI (active with 'ui' profile)
|   +-- config-pgvector/        <-- PgVector auto-configuration
|   +-- data/                   <-- Shared datasets (bikes, customers, products, orders)
|
+-- mcp/                        <-- Model Context Protocol demos
|   +-- 01-basic-stdio-mcp-server/
|   +-- 02-basic-http-mcp-server/
|   +-- 03-basic-mcp-client/
|   +-- 04-dynamic-tool-calling/
|   +-- 05-mcp-capabilities/
|
+-- agentic-system/             <-- Agentic AI patterns
|   +-- 01-inner-monologue/
|   +-- 02-model-directed-loop/
|
+-- docker/                     <-- Infrastructure
|   +-- postgres/               <-- PostgreSQL + pgvector + pgAdmin
|   +-- observability-stack/    <-- Grafana LGTM (logs, traces, metrics)
|
+-- docs/                       <-- Workshop documentation
```

### Key Design Principle

**Component modules are provider-independent.** You write the AI logic once in `components/`, then run it with any provider app. The Spring AI abstraction layer handles the provider differences.

---

## Workshop Demo Flow

The recommended learning path, from fundamentals to advanced patterns.

### Stage 1: Chat Fundamentals

**Module: `components/apis/chat/`**

Start a provider app and work through the chat examples in order:

| Demo | Endpoint | Concept |
|------|----------|---------|
| **chat_01** | `GET /chat/01/joke?topic=spring` | Simplest AI call: `chatModel.call(String)` |
| **chat_02** | `GET /chat/02/client/joke?topic=java` | ChatClient fluent API: `.prompt().user().call().content()` |
| **chat_02** | `GET /chat/02/model/joke?topic=java` | ChatModel with Prompt object and ChatResponse |
| **chat_03** | `GET /chat/03/joke?adjective=funny&topic=cats` | Prompt templates with `{variables}` |
| **chat_04** | `GET /chat/04/plays/list` | Structured output: response -> `List<String>` |
| **chat_04** | `GET /chat/04/plays/map` | Structured output: response -> `Map<String, Object>` |
| **chat_04** | `GET /chat/04/plays/object` | Structured output: response -> `Play[]` (Java records) |
| **chat_05** | `GET /chat/05/time?tz=Europe/Berlin` | Tool/Function calling: AI calls your Java code |
| **chat_05** | `GET /chat/05/weather?city=Berlin` | Tool calling: weather function |
| **chat_05** | `GET /chat/05/search?query=...` | Tool calling: restaurant search with `returnDirect` |
| **chat_06** | `GET /chat/06/fruit` | System roles: AI as a fruit expert |
| **chat_06** | `GET /chat/06/veg` | System roles: AI as a vegetable expert |
| **chat_07** | `GET /chat/07/explain` | Multimodal: send image + text, get description |
| **chat_08** | `GET /chat/08/essay?topic=spring` | Streaming: `Flux<String>` server-sent events |

**Key takeaways:**
- ChatModel (low-level) vs ChatClient (fluent, preferred)
- Prompt templates for dynamic content
- Structured output for type-safe responses
- Tool calling lets AI invoke your Java methods
- System prompts define AI personality/expertise
- Multimodal auto-switches to `llava` model on Ollama

---

### Stage 2: Embeddings

**Module: `components/apis/embedding/`**

| Demo | Endpoint | Concept |
|------|----------|---------|
| **embed_01** | `GET /embed/01/text?text=hello` | Generate embedding vector from text |
| **embed_01** | `GET /embed/01/dimension` | Check model dimensions (768 for nomic-embed-text, 1536 for OpenAI) |
| **embed_02** | `GET /embed/02/words` | Cosine similarity between word pairs |
| **embed_02** | `GET /embed/02/quotes` | Semantic search: find most similar quote |
| **embed_03** | `GET /embed/03/big` | Embed a large document (Shakespeare) — shows context limits |
| **embed_03** | `GET /embed/03/chunk` | TokenTextSplitter: chunk large docs before embedding |
| **embed_04** | `GET /embed/04/json/bikes` | Document readers: JSON -> embeddings |
| **embed_04** | `GET /embed/04/text/works` | Document readers: plain text -> embeddings |
| **embed_04** | `GET /embed/04/pdf/pages` | Document readers: PDF (per page) -> embeddings |
| **embed_04** | `GET /embed/04/pdf/para` | Document readers: PDF (per paragraph) -> embeddings |

**Key takeaways:**
- Embeddings are dense float vectors representing semantic meaning
- Similar texts have high cosine similarity scores
- Large documents must be chunked before embedding (TokenTextSplitter)
- Multiple document readers (JSON, Text, PDF) for the ETL pipeline

---

### Stage 3: Vector Stores

**Module: `components/apis/vector-store/`**

| Demo | Endpoint | Concept |
|------|----------|---------|
| **vector_01** | `GET /vector/01/load` | Load bike documents into vector store (with chunking) |
| **vector_01** | `GET /vector/01/query?topic=mountain` | Semantic similarity search |

**Two backends** (profile-based):
- Default: `SimpleVectorStore` (in-memory, no infrastructure)
- `pgvector` profile: `PgVectorStore` (PostgreSQL, persistent, production-ready)

**Key takeaways:**
- VectorStore abstraction: same code, different backends
- Documents are chunked with `TokenTextSplitter` before embedding for Ollama compatibility
- `similaritySearch()` finds semantically relevant documents
- PgVector uses HNSW index with cosine distance, **768 dimensions** (nomic-embed-text)
- If switching embedding models, drop `vector_store` table to reset dimensions

---

### Stage 4: AI Patterns

**Module: `components/patterns/`**

#### 4a: Stuff the Prompt

| Demo | Endpoint | Concept |
|------|----------|---------|
| **01** | `GET /stuffit/01/query?topic=bikes` | Manually inject context into the prompt |

Simple but effective: put relevant data directly into the system/user prompt.

#### 4b: Retrieval Augmented Generation (RAG)

| Demo | Endpoint | Concept |
|------|----------|---------|
| **rag_01** | `GET /rag/01/load` | Load bike data into vector store (72 chunks from 25 docs) |
| **rag_01** | `GET /rag/01/query?topic=mountain` | Manual RAG: search -> stuff -> generate |
| **rag_02** | `GET /rag/02/load` | Load data for advisor-based RAG |
| **rag_02** | `GET /rag/02/query?topic=commuter` | QuestionAnswerAdvisor: automatic RAG |

**Two approaches:**
1. Manual: `vectorStore.similaritySearch()` -> build prompt -> `chatClient.call()`
2. Advisor: `QuestionAnswerAdvisor` handles search + prompt augmentation automatically

**Note:** Call `/load` before `/query` — data must be loaded into the vector store first.

#### 4c: Chat Memory

| Demo | Endpoint | Concept |
|------|----------|---------|
| **mem_02** | `GET /mem/02/hello?message=Hi+I+am+Alice` | Send message with memory |
| **mem_02** | `GET /mem/02/name` | Ask "What's my name?" — AI remembers from context |

**Two memory advisors:**
- `MessageChatMemoryAdvisor` — adds history as message list
- `PromptChatMemoryAdvisor` — injects history into the prompt text

---

### Stage 5: Advanced Agent Patterns

#### 5a: Chain of Thought

**Module: `components/patterns/chain-of-thought/`**

| Demo | Endpoint | Concept |
|------|----------|---------|
| | `GET /cot/bio/oneshot` | Single-pass bio generation |
| | `GET /cot/bio/flow` | Multi-step: outline -> draft -> refine -> polish (~10s) |

Shows how breaking a task into steps produces dramatically better output.
Requires `Profile.pdf` in classpath (sample included in repo).

#### 5b: Self-Reflection Agent

**Module: `components/patterns/self-reflection-agent/`**

| Demo | Endpoint | Concept |
|------|----------|---------|
| | `GET /reflection/bio/oneshot` | Single-pass (baseline) |
| | `GET /reflection/bio/agent?iterations=3` | Writer + Critic loop with N iterations |

Architecture: Writer generates -> Critic reviews -> Writer revises -> repeat.
Requires `Profile.pdf` in classpath (sample included in repo).

---

### Stage 6: Model Context Protocol (MCP)

**Module: `mcp/`**

| Demo | Module | Concept |
|------|--------|---------|
| **01** | basic-stdio-mcp-server | MCP server communicating via stdin/stdout |
| **02** | basic-http-mcp-server | MCP server over Streamable HTTP |
| **03** | basic-mcp-client | MCP client connecting to servers |
| **04** | dynamic-tool-calling | Runtime tool registration and discovery |
| **05** | mcp-capabilities | Full showcase: tools, resources, prompts, completions |

MCP enables AI models to discover and use tools dynamically at runtime — the protocol behind tool calling in production systems.

**Note:** Each MCP module runs as a **separate Spring Boot app** (not part of provider-ollama/openai). MCP servers are provider-independent; MCP clients are configured for OpenAI by default.

---

### Stage 7: Agentic Systems

**Module: `agentic-system/`**

#### 7a: Inner Monologue Agent

The agent "thinks out loud" — visible reasoning steps before responding.

```
POST /agents/inner-monologue/{id}          # Create agent
POST /agents/inner-monologue/{id}/messages  # Send message
GET  /agents/inner-monologue/{id}          # Get agent state
```

Uses `OpenAiChatOptions.toolChoice("required")` to force tool use, `MessageChatMemoryAdvisor` for conversation persistence.

#### 7b: Model-Directed Loop

The agent decides whether to continue processing or return a final answer.

```
POST /agents/model-directed-loop/{id}          # Create agent
POST /agents/model-directed-loop/{id}/messages  # Send message
GET  /agents/model-directed-loop/{id}          # Get agent + trace
```

Returns a `ChatTraceResponse` with all intermediate reasoning steps visible.

Both agents also have CLI interfaces via Spring Shell 4 (`inner-monologue-cli`, `model-directed-loop-cli`).

**Note:** Agent apps currently require OpenAI provider. Could be migrated to `ToolCallingChatOptions` for provider-agnostic support (Spring AI 2.0).

---

### Stage 8: Observability

**New capability with Spring Boot 4 + OpenTelemetry.**

| Topic | What to Show |
|-------|-------------|
| Distributed tracing | Trace from HTTP request -> ChatClient -> AI provider API (via OTLP -> Tempo) |
| Span hierarchy | @TracedEndpoint -> @TracedService -> @TracedRepository -> DB |
| Metrics | JVM, connection pools, HTTP requests via Micrometer (OTLP -> Mimir) |
| Logs | Correlated logs with trace IDs (Logback OTel appender -> Loki) |
| Dashboards | JVM Micrometer, HikariCP/JDBC, Spring Boot Microservices |

Run with `observation` profile and open Grafana at http://localhost:3000.

**Infrastructure:** Single `grafana/otel-lgtm:latest` container provides Grafana, Loki, Tempo, Mimir, and OTel Collector.

**Custom tracing annotations** available in `04-distributed-tracing` module:
- `@TracedEndpoint` — controller methods (SpanKind.SERVER)
- `@TracedService` — service methods (SpanKind.INTERNAL)
- `@TracedRepository` — repository methods (SpanKind.CLIENT)

---

## AI Provider Options

### Provider Matrix

| Provider | Chat | Embedding | Multimodal | Tool Calling | Local | Cost | Tested |
|----------|------|-----------|------------|--------------|-------|------|:------:|
| **Ollama** | qwen3 (8B) | nomic-embed-text | llava (auto) | Yes | Yes | Free | 44/44 |
| **OpenAI** | gpt-4o-mini | text-embedding-3 | gpt-4o | Yes | No | Pay-per-use | 44/44 |
| **Anthropic** | Claude | - | Claude 3+ | Yes | No | Pay-per-use | 14/14 |
| **Azure OpenAI** | gpt-4.1-mini | text-embedding-3 | gpt-4o | Yes | No | Enterprise | 8/8 |
| **Google** | Gemini 2.5 Flash | text-embedding-004 | Gemini | Yes | No | Pay-per-use | 13/13 |
| **AWS Bedrock** | Amazon Nova Lite | - | - | Yes | No | Enterprise | 8/8 |

### Choosing a Provider

| Use Case | Recommended Provider | Why |
|----------|---------------------|-----|
| **Workshop / Offline** | Ollama | Free, no API keys, all 44 demos work |
| **Full feature demos** | OpenAI | Chat + image + audio + multimodal + tools |
| **Best reasoning** | Anthropic or OpenAI | Claude 4 / GPT-4o for complex tasks |
| **Enterprise / Compliance** | Azure OpenAI or AWS Bedrock | Data residency, SLAs, corporate billing |
| **Cost-conscious** | Ollama or OpenAI gpt-4o-mini | Free (local) or very cheap (cloud) |
| **Google Cloud users** | Google Vertex AI / GenAI | Native GCP integration |

### Ollama Model Details

| Model | Purpose | Params | RAM | Embedding Dims |
|-------|---------|--------|-----|----------------|
| `qwen3` | Chat (default) | 8B | ~8GB | - |
| `nomic-embed-text` | Embeddings (default) | 137M | ~1GB | 768 |
| `llava` | Multimodal — auto-used for chat_07 | 7B | ~8GB | - |
| `llama3.2` | Optional: fast chat for simple demos | 3B | ~4GB | - |

**16 GB macOS:** `qwen3` + `nomic-embed-text` = ~10 GB active. `llava` loads on-demand for chat_07 only.

---

## Spring Profiles

### Available Profiles

| Profile | Purpose | Infrastructure Needed |
|---------|---------|----------------------|
| (none) | Default: in-memory vector store, no tracing | None |
| `pgvector` | Use PostgreSQL pgvector for persistent vectors | PostgreSQL Docker |
| `spy` | Route API calls through gateway for inspection | Gateway app running |
| `observation` | Full observability: traces + metrics + logs | LGTM Docker stack |

### Combining Profiles

```bash
# Full-featured local setup (recommended for workshop)
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation

# Cloud provider with network spy
./mvnw spring-boot:run -pl applications/provider-openai \
  -Dspring-boot.run.profiles=spy,pgvector
```

---

## Gateway Spy Architecture

The gateway application (`applications/gateway/`) acts as a transparent proxy that logs all API traffic.

```
Your App --> Gateway (:7777) --> AI Provider API
                 |
                 +-- Logs request body & headers
                 +-- Logs response body & headers
```

**Note:** Gateway port 7777 may conflict with local MCP servers. Shut down MCP server before starting gateway.

### Routes

| Path | Destination |
|------|------------|
| `/openai/**` | `https://api.openai.com/v1/chat/completions` |
| `/anthropic/**` | `https://api.anthropic.com` |
| `/ollama/**` | `http://localhost:11434/` |

### How to Use

1. Start the gateway: `./mvnw spring-boot:run -pl applications/gateway`
2. Start your provider with `spy` profile
3. All API calls route through the gateway — check gateway logs for full request/response details

Uses `AuditLogEntry` to capture body, headers, and destination URI for every request.

---

## Running Specific Demos

### Quick Reference

```bash
# Start infrastructure (once)
docker compose -f docker/postgres/docker-compose.yaml up -d
docker compose -f docker/observability-stack/docker-compose.yaml up -d
ollama serve

# Pull required models
ollama pull qwen3 && ollama pull nomic-embed-text && ollama pull llava

# Pick a provider and run
./mvnw spring-boot:run -pl applications/provider-ollama -Dspring-boot.run.profiles=pgvector,observation

# Then hit endpoints
curl "http://localhost:8080/chat/01/joke?topic=spring"
curl "http://localhost:8080/embed/01/dimension"
curl "http://localhost:8080/rag/01/load"
curl "http://localhost:8080/rag/01/query?topic=mountain+bike"
```

### Module Dependencies

| Demo | Requires pgvector | Requires observation | Provider-specific |
|------|:-:|:-:|-------------------|
| chat_01 - chat_06 | No | No | Any |
| chat_07 (multimodal) | No | No | Any (auto-switches to llava on Ollama) |
| chat_08 (streaming) | No | No | Any |
| embed_01 - embed_04 | No | No | Any with embeddings |
| vector_01 | Recommended | No | Any with embeddings |
| RAG (01, 02) | Recommended | No | Any with embeddings |
| Chat memory | No | No | Any |
| CoT / Reflection | No | No | Any (requires Profile.pdf — included) |
| MCP servers | No | No | Independent (separate apps) |
| MCP clients | No | No | OpenAI (configured) |
| Agentic agents | No | No | OpenAI (uses OpenAiChatOptions) |
| Agentic CLIs | No | No | Any (Spring Shell 4) |
| Distributed tracing | No | Yes | Any |
