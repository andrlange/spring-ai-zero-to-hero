# Full Workshop Guide

Complete walkthrough of all 8 stages for self-paced learners. Covers every demo, the concepts behind it, and the code to look at.

**Tech stack:** Spring Boot 4.0.5 | Spring AI 2.0.0-M4 | Java 25 | Spring Framework 7

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
|   +-- 01-mcp-stdio-server/
|   +-- 02-mcp-http-server/
|   +-- 03-mcp-client/
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
    +-- quickstart.md           <-- 5-minute setup for live workshops
    +-- guide.md                <-- Full walkthrough (this file)
    +-- providers.md            <-- Provider comparison and setup
    +-- troubleshooting.md      <-- Common issues and solutions
```

### Key design principle

**Component modules are provider-independent.** The AI logic lives in `components/` and works with any provider application. The Spring AI abstraction layer — `ChatModel`, `EmbeddingModel`, `VectorStore` — handles provider differences. You write the code once; you pick the provider at startup.

---

## Spring Profiles

Profiles control which infrastructure and features are active.

| Profile | Purpose | Infrastructure needed |
|---------|---------|----------------------|
| (none) | In-memory vector store, no tracing | None |
| `pgvector` | PostgreSQL pgvector for persistent vectors | PostgreSQL Docker |
| `spy` | Route API calls through gateway for inspection | Gateway app running |
| `observation` | Full observability: traces, metrics, logs | LGTM Docker stack |

### Combining profiles

```bash
# Full-featured local setup (recommended for workshop)
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation

# Cloud provider with network spy
./mvnw spring-boot:run -pl applications/provider-openai \
  -Dspring-boot.run.profiles=spy,pgvector
```

---

## Infrastructure Setup

```bash
# Start PostgreSQL with pgvector
docker compose -f docker/postgres/docker-compose.yaml up -d

# Start observability stack (Grafana, Loki, Tempo, Mimir, OTel Collector)
docker compose -f docker/observability-stack/docker-compose.yaml up -d

# Ollama (optional — only needed for local provider)
# ollama serve
# ollama pull qwen3 && ollama pull nomic-embed-text && ollama pull llava

# For cloud providers, configure API keys instead:
# ./workshop.sh creds
```

---

## Stage 1: Chat Fundamentals

**Module:** `components/apis/chat/`

Start here. Each demo introduces a new layer of the Spring AI chat API.

| Demo | Endpoint | Concept |
|------|----------|---------|
| chat_01 | `GET /chat/01/joke?topic=spring` | Simplest AI call: `chatModel.call(String)` |
| chat_02 client | `GET /chat/02/client/joke?topic=java` | ChatClient fluent API: `.prompt().user().call().content()` |
| chat_02 model | `GET /chat/02/model/joke?topic=java` | ChatModel with Prompt object and ChatResponse |
| chat_03 | `GET /chat/03/joke?adjective=funny&topic=cats` | Prompt templates with `{variables}` |
| chat_04 list | `GET /chat/04/plays/list` | Structured output: response as `List<String>` |
| chat_04 map | `GET /chat/04/plays/map` | Structured output: response as `Map<String, Object>` |
| chat_04 object | `GET /chat/04/plays/object` | Structured output: response as `Play[]` Java records |
| chat_05 time | `GET /chat/05/time?tz=Europe/Berlin` | Tool calling: AI calls your Java method |
| chat_05 weather | `GET /chat/05/weather?city=Berlin` | Tool calling: named function bean |
| chat_05 search | `GET /chat/05/search?query=italian+for+4` | Tool calling with `returnDirect` |
| chat_06 fruit | `GET /chat/06/fruit` | System roles: AI as a fruit expert |
| chat_06 veg | `GET /chat/06/veg` | System roles: AI as a vegetable expert |
| chat_07 | `GET /chat/07/explain` | Multimodal: image + text input |
| chat_08 | `GET /chat/08/essay?topic=spring` | Streaming: `Flux<String>` server-sent events |

### Code to look at

- `components/apis/chat/src/main/java/` — one package per demo (chat_01 through chat_08)
- `chat_01`: `BasicPromptController.java` — direct `chatModel.call(String)`
- `chat_02`: compare `ChatClientController` vs `ChatModelController`
- `chat_04`: `StructuredOutputController.java` — `BeanOutputConverter` and `ListOutputConverter`
- `chat_05`: `ToolCallingController.java` + tool class annotated with `@Tool`
- `chat_08`: `StreamingController.java` — returns `Flux<String>`

### Key takeaways

- `ChatModel` is the low-level API; `ChatClient` is the fluent, preferred API
- Prompt templates use `{variable}` placeholders, resolved at runtime
- Structured output uses output converters to deserialize responses into Java types
- Tool calling lets the AI invoke annotated Java methods — the model decides when to call them
- System prompts define the AI's persona or expertise for a conversation
- On Ollama, chat_07 auto-switches to the `llava` multimodal model

---

## Stage 2: Embeddings

**Module:** `components/apis/embedding/`

Embeddings turn text into dense float vectors. Similar texts produce vectors close together in high-dimensional space — that is the foundation of semantic search.

| Demo | Endpoint | Concept |
|------|----------|---------|
| embed_01 text | `GET /embed/01/text?text=hello` | Generate an embedding vector from text |
| embed_01 dim | `GET /embed/01/dimension` | Check model dimensions (768 for nomic-embed-text) |
| embed_02 words | `GET /embed/02/words` | Cosine similarity between word pairs |
| embed_02 quotes | `GET /embed/02/quotes` | Semantic search: find the most similar quote |
| embed_03 big | `GET /embed/03/big` | Embed a large document — shows context limits |
| embed_03 chunk | `GET /embed/03/chunk` | TokenTextSplitter: chunk large docs before embedding |
| embed_04 json | `GET /embed/04/json/bikes` | Document reader: JSON to embeddings |
| embed_04 text | `GET /embed/04/text/works` | Document reader: plain text to embeddings |
| embed_04 pdf pages | `GET /embed/04/pdf/pages` | Document reader: PDF per-page to embeddings |
| embed_04 pdf para | `GET /embed/04/pdf/para` | Document reader: PDF per-paragraph to embeddings |

### Code to look at

- `components/apis/embedding/src/main/java/` — packages embed_01 through embed_04
- `embed_02`: `SimilarityController.java` — cosine similarity calculation
- `embed_03`: `ChunkingController.java` — `TokenTextSplitter` usage
- `embed_04`: `DocumentReaderController.java` — `JsonReader`, `TextReader`, `PagePdfDocumentReader`, `ParagraphPdfDocumentReader`

### Key takeaways

- Embeddings are float arrays (768 dims for nomic-embed-text, 1536 for OpenAI)
- Cosine similarity measures semantic closeness between 0 and 1
- Documents exceeding the model's context window (8192 tokens for nomic-embed-text) must be chunked first
- `TokenTextSplitter` splits text into chunks while respecting token boundaries
- Multiple document readers handle different input formats in the ETL pipeline

---

## Stage 3: Vector Stores

**Module:** `components/apis/vector-store/`

A vector store persists embeddings and enables similarity search. Spring AI's `VectorStore` abstraction means your code works with any backend.

| Demo | Endpoint | Concept |
|------|----------|---------|
| vector_01 load | `GET /vector/01/load` | Load bike documents into the vector store with chunking |
| vector_01 query | `GET /vector/01/query?topic=mountain` | Semantic similarity search |

**Two backends, same code:**

- Default (no profile): `SimpleVectorStore` — in-memory, no infrastructure needed
- `pgvector` profile: `PgVectorStore` — PostgreSQL, persistent, production-ready

Always call `/load` before `/query`. The vector store must be populated before it can answer queries.

### Code to look at

- `components/apis/vector-store/src/main/java/`
- `VectorStoreController.java` — `vectorStore.add()` and `vectorStore.similaritySearch()`
- `components/config-pgvector/` — PgVector auto-configuration activated by the `pgvector` profile

### Key takeaways

- `VectorStore.add(List<Document>)` — embed and store documents
- `VectorStore.similaritySearch(SearchRequest)` — find semantically related documents
- PgVector uses an HNSW index with cosine distance at 768 dimensions (nomic-embed-text)
- `TokenTextSplitter` is applied before `add()` because raw bike documents exceed Ollama's context window
- If you switch embedding models, you must drop the `vector_store` table (see [Troubleshooting](troubleshooting.md))

---

## Stage 4: AI Patterns

**Module:** `components/patterns/`

### 4a: Stuff the Prompt

| Demo | Endpoint | Concept |
|------|----------|---------|
| stuffit_01 | `GET /stuffit/01/query?topic=bikes` | Manually inject context into the prompt |

The simplest retrieval approach: fetch relevant data, put it directly in the system or user prompt. No vector store required — works with any data source.

**Code:** `components/patterns/stuff-prompt/src/main/java/`

### 4b: Retrieval Augmented Generation (RAG)

Always call `/load` before `/query`. The vector store must contain data before queries will return meaningful answers.

| Demo | Endpoint | Concept |
|------|----------|---------|
| rag_01 load | `GET /rag/01/load` | Load bike data into vector store (72 chunks from 25 docs) |
| rag_01 query | `GET /rag/01/query?topic=mountain` | Manual RAG: search, stuff, generate |
| rag_02 load | `GET /rag/02/load` | Load data for advisor-based RAG |
| rag_02 query | `GET /rag/02/query?topic=commuter` | QuestionAnswerAdvisor: automatic RAG pipeline |

**Two RAG approaches:**

1. Manual (rag_01): `vectorStore.similaritySearch()` → build prompt with context → `chatClient.call()`
2. Advisor (rag_02): `QuestionAnswerAdvisor` handles the search + prompt augmentation automatically as a ChatClient advisor

**Code:** `components/patterns/rag/src/main/java/`

### 4c: Chat Memory

| Demo | Endpoint | Concept |
|------|----------|---------|
| mem_02 hello | `GET /mem/02/hello?message=Hi+I+am+Alice` | Send a message with memory |
| mem_02 name | `GET /mem/02/name` | Ask "What's my name?" — AI recalls from context |

The demo uses `MessageChatMemoryAdvisor` (adds history as a message list) and `PromptChatMemoryAdvisor` (injects history into the prompt text). Try the two endpoints in sequence with the same conversation ID.

**Code:** `components/patterns/chat-memory/src/main/java/`

---

## Stage 5: Advanced Agent Patterns

### 5a: Chain of Thought

**Module:** `components/patterns/chain-of-thought/`

| Demo | Endpoint | Concept |
|------|----------|---------|
| cot oneshot | `GET /cot/bio/oneshot` | Single-pass biography generation |
| cot flow | `GET /cot/bio/flow` | Multi-step: outline → draft → refine → polish |

The `flow` endpoint makes multiple sequential LLM calls, each building on the previous step's output. This takes ~10 seconds with Ollama (multiple round trips) but produces dramatically better output than a single-pass request.

Requires `Profile.pdf` in the classpath — a sample is included in the repository.

### 5b: Self-Reflection Agent

**Module:** `components/patterns/self-reflection-agent/`

| Demo | Endpoint | Concept |
|------|----------|---------|
| reflection oneshot | `GET /reflection/bio/oneshot` | Single-pass baseline |
| reflection agent | `GET /reflection/bio/agent?iterations=3` | Writer + Critic loop with N iterations |

Architecture: a Writer LLM generates content, a Critic LLM reviews it and suggests improvements, the Writer revises — repeated N times. Each iteration improves on the last.

Requires `Profile.pdf` in the classpath — a sample is included in the repository.

---

## Stage 6: Model Context Protocol (MCP)

**Module:** `mcp/`
**Dashboard:** http://localhost:8080/dashboard/stage/6

MCP lets AI models discover and use tools at runtime. Five demos — each runs as a **separate Spring Boot application**.

| Demo | Module | Transport | Port | Purpose |
|------|--------|-----------|------|---------|
| 01 | `01-mcp-stdio-server` | STDIO | — (subprocess per request) | MCP server via stdin/stdout |
| 02 | `02-mcp-http-server` | Streamable HTTP | 8081 | MCP server over HTTP |
| 03 | `03-mcp-client` | Client | — | ChatClient + ToolCallbackProvider using MCP servers |
| 04 server | `04-dynamic-tool-calling/server` | Streamable HTTP | 8082 | Runtime tool registration (`McpSyncServer.addTool`) |
| 04 client | `04-dynamic-tool-calling/client` | HTTP | — | Client that discovers newly added tools |
| 05 | `05-mcp-capabilities` | Streamable HTTP | 8083 | Full showcase: tools, resources, prompts, completions |

**Start everything via the workshop script:**

```bash
./workshop.sh mcp start all       # builds 01 jar + starts 02/04/05
./workshop.sh mcp status          # table of demo | port | pid | up?
./workshop.sh mcp stop all        # stop them
./workshop.sh mcp logs 04         # tail a specific demo's log
```

Once started, open **http://localhost:8080/dashboard/stage/6** and click the action buttons on each card to list tools / invoke / trigger dynamic registration / read resources / get prompts. Each card has a **Docs** button that opens the full `SPRING_AI_STAGE_6.md` section in a modal.

**Advanced: direct Maven invocation** — if you prefer classic `spring-boot:run`, each module starts individually:

```bash
./mvnw spring-boot:run -pl mcp/02-mcp-http-server                       # :8081
./mvnw spring-boot:run -pl mcp/04-dynamic-tool-calling/server           # :8082
./mvnw spring-boot:run -pl mcp/05-mcp-capabilities                      # :8083
./mvnw spring-boot:run -pl mcp/03-mcp-client                            # local mode
./mvnw spring-boot:run -pl mcp/03-mcp-client \
    -Dspring-boot.run.profiles=mcp-external                             # Brave+filesystem
```

MCP servers are provider-independent. MCP clients (03, 04) are configured for OpenAI by default.

---

## Stage 7: Agentic Systems

**Module:** `agentic-system/`

Each agentic module includes both a REST API application and a CLI application built with Spring Shell 4.

### 7a: Inner Monologue Agent

The agent "thinks out loud" — reasoning steps are visible before the final response.

```
POST /agents/inner-monologue/{id}           Create agent
POST /agents/inner-monologue/{id}/messages  Send message
GET  /agents/inner-monologue/{id}           Get agent state
```

Uses `OpenAiChatOptions.toolChoice("required")` to force the model to use tools, and `MessageChatMemoryAdvisor` for conversation persistence. The inner monologue reasoning appears as tool call intermediates.

CLI: `./mvnw spring-boot:run -pl agentic-system/01-inner-monologue` — then use shell commands

### 7b: Model-Directed Loop Agent

The agent decides at each iteration whether to continue processing or return a final answer.

```
POST /agents/model-directed-loop/{id}           Create agent
POST /agents/model-directed-loop/{id}/messages  Send message
GET  /agents/model-directed-loop/{id}           Get agent + trace
```

Returns a `ChatTraceResponse` with all intermediate reasoning steps visible. Use the GET endpoint to inspect the full trace after sending a message.

CLI: `./mvnw spring-boot:run -pl agentic-system/02-model-directed-loop`

**Note:** Both agent REST apps currently require OpenAI (`OpenAiChatOptions`). The CLI modules work with any provider. A future migration to `ToolCallingChatOptions` would make the agents provider-agnostic.

---

## Stage 8: Observability

**New capability with Spring Boot 4 + OpenTelemetry.**

Run any provider app with the `observation` profile:

```bash
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation
```

Then open Grafana at http://localhost:3000.

### What to explore

| Signal | Where to look in Grafana | What you see |
|--------|--------------------------|--------------|
| Distributed traces | Explore > Tempo | Full trace from HTTP request through ChatClient to AI provider API |
| Span hierarchy | Trace detail view | `@TracedEndpoint` → `@TracedService` → `@TracedRepository` spans |
| Metrics | Explore > Mimir | JVM memory, HTTP request rates, HikariCP pool stats |
| Logs | Explore > Loki | Correlated logs with trace IDs you can click to jump to the trace |
| Dashboards | Dashboards menu | Pre-provisioned: JVM Micrometer, Spring Boot Microservices, HikariCP |

### Telemetry flow

```
Spring Boot App
  |-- Traces  --> OTLP HTTP (:4318/v1/traces)  --> OTel Collector --> Tempo
  |-- Metrics --> OTLP HTTP (:4318/v1/metrics) --> OTel Collector --> Mimir
  +-- Logs    --> OTLP HTTP (:4318/v1/logs)    --> OTel Collector --> Loki
                                                          |
                                                      Grafana (:3000)
```

### Custom tracing annotations

Available in the `04-distributed-tracing` module under `components/patterns/`:

- `@TracedEndpoint` — marks a controller method as a SERVER span
- `@TracedService` — marks a service method as an INTERNAL span
- `@TracedRepository` — marks a repository method as a CLIENT span

These create nested spans that appear as a hierarchy in the Tempo trace view.

### Infrastructure

The `docker/observability-stack/docker-compose.yaml` runs a single `grafana/otel-lgtm` container that provides Grafana, Loki, Tempo, Mimir, and the OTel Collector — one container for all signals.

---

## Gateway Spy

The gateway application is a transparent proxy that logs all traffic between your provider app and the AI API.

```
Your App --> Gateway (:7777) --> AI Provider API
                 |
                 +-- logs request body & headers
                 +-- logs response body & headers
```

**Routes:**

| Path | Destination |
|------|------------|
| `/openai/**` | `https://api.openai.com/v1/chat/completions` |
| `/anthropic/**` | `https://api.anthropic.com` |
| `/ollama/**` | `http://localhost:11434/` |

**How to use:**

1. Start the gateway: `./mvnw spring-boot:run -pl applications/gateway`
2. Start your provider with the `spy` profile
3. All AI API calls route through the gateway — check the gateway logs for full request and response bodies

---

## Module Dependency Reference

| Demo | pgvector needed | observation needed | Provider restriction |
|------|-----------------|--------------------|----------------------|
| chat_01 – chat_06 | No | No | Any |
| chat_07 (multimodal) | No | No | Any (auto-switches to llava on Ollama) |
| chat_08 (streaming) | No | No | Any |
| embed_01 – embed_04 | No | No | Any with EmbeddingModel |
| vector_01 | Recommended | No | Any with EmbeddingModel |
| RAG 01, 02 | Recommended | No | Any with EmbeddingModel |
| Chat memory | No | No | Any |
| CoT / Reflection | No | No | Any (Profile.pdf included) |
| MCP servers | No | No | None (standalone) |
| MCP clients | No | No | OpenAI (configured) |
| Agentic agents (REST) | No | No | OpenAI |
| Agentic CLIs | No | No | Any |
| Distributed tracing | No | Yes | Any |

---

## Quick reference: run commands

```bash
# Start infrastructure (once)
docker compose -f docker/postgres/docker-compose.yaml up -d
docker compose -f docker/observability-stack/docker-compose.yaml up -d
ollama serve

# Pull Ollama models
ollama pull qwen3 && ollama pull nomic-embed-text && ollama pull llava

# Run Ollama provider with everything
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation

# Hit endpoints
curl "http://localhost:8080/chat/01/joke?topic=spring"
curl "http://localhost:8080/embed/01/dimension"
curl "http://localhost:8080/rag/01/load"
curl "http://localhost:8080/rag/01/query?topic=mountain+bike"
```
