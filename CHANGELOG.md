# Changelog — Spring AI Zero-to-Hero Workshop

## [2.1.0] — 2026-04-04: Workshop Helpers, Dashboard UI & Docs

Workshop improvements for presenters and self-learners: interactive dashboard, OpenAPI docs, unified CLI script, and restructured documentation.

### New Modules

#### `components/config-openapi` — Swagger UI & OpenAPI Specs
- SpringDoc OpenAPI 3.0.1 with `@OpenAPIDefinition` for 5 workshop stage tags
- OpenAPI annotations on all 21 controllers (37 endpoints documented)
- Server-side path sorting for correct endpoint ordering
- Always active — Swagger UI at `/swagger-ui.html`, OpenAPI spec at `/v3/api-docs`

#### `components/config-dashboard` — Workshop Dashboard UI
- Thymeleaf + Bootstrap 5.3.3 (dark theme) + htmx 2.0.4
- Activated with `ui` profile, served at `/dashboard`
- Spring-branded dark theme with collapsible sidebar
- All frontend assets vendored locally for offline workshop use
- Auto-discovers endpoints from OpenAPI spec at runtime
- Specialized response views: plain text, JSON viewer, streaming text, similarity bar charts, chat bubbles, step accordion
- Parameter inputs with placeholder examples, dropdown selects for enum params
- Copy-to-clipboard curl command with live parameter updates
- Chat-style conversation view for Stage 4 (patterns) endpoints
- Dashboard excluded from tracing via `ObservationPredicate`

### `workshop.sh` — Unified CLI Script
- Replaces `check-deps.sh` and `download-deps.sh`
- CLI mode: `check`, `setup`, `start`, `stop`, `reset`, `status`, `logs`, `infra`
- Interactive TUI menu with provider selection and profile toggling
- Infrastructure submenu: start PostgreSQL, LGTM, or both
- Abort option (`a`) in all submenus
- Database reset: drops and recreates public schema in all 3 databases
- Port 8080 check before starting (lsof on macOS, ss on Linux)
- Process group kill on stop (Maven + forked Java)
- Runs `mvn install` before `spring-boot:run` for module dependency resolution
- Health check via `/v3/api-docs` fallback (not all providers have actuator)
- Compatible with macOS bash 3.2 and Linux bash 4+

### Documentation Restructure
- `docs/README.md` — landing page with audience routing
- `docs/quickstart.md` — 5-minute setup for live workshop attendees
- `docs/guide.md` — full 8-stage walkthrough for self-learners
- `docs/providers.md` — provider comparison, credentials, model requirements
- `docs/troubleshooting.md` — common issues and solutions
- Fixed all example docs (`examples_chat.md`, `examples_embedding.md`, `examples_image.md`, `examples_audio.md`) with correct URLs
- Root `README.md` updated with screenshots, docs links, and workshop.sh instructions

### Observability Fixes
- Suppressed generic `http.server.requests` spans — `@TracedEndpoint` spans are now root spans
- Trace root span names show HTTP request path (e.g., `GET /rag/02/query`)
- Fixed Grafana LGTM datasource provisioning for trace-to-log correlation
- Enabled OTel logging export with explicit `enabled: true`

### MCP Fixes (Stage 6)
- Added `protocol: STREAMABLE` and `streamable-http.mcp-endpoint: /mcp` to MCP 02, 04, 05
- Without this config, the Streamable HTTP transport didn't register the `/mcp` endpoint
- All 4 MCP servers tested and passing

### Agentic Fixes (Stage 7)
- Fixed model-directed-loop agent reinvocation loop: first call sent user message but discarded result, then loop sent empty prompts. Now sends user message in first iteration
- Both agents tested with OpenAI and passing

### Endpoint Fixes
- `/embed/01/dimension` — shows provider, model name, and dimensions
- `/embed/01/text` — added `text` request parameter
- `/embed/03/big` — added `size` parameter (small/large dropdown)
- `/chat/02/*/threeJokes` — makes 3 separate API calls (not 1)
- `/chat/05/dayOfWeek` — system prompt forces tool call; TimeTools returns day-of-week
- `/chat/07/explain` — fixed OpenAPI example to match actual image
- `/cot/bio/oneshot` — removed unused `message` parameter
- Fixed Ollama Flyway migration dimension: 1024 → 768
- Removed duplicate `spring-boot-starter-actuator` from provider-openai
- Hidden `/login` endpoint from OpenAPI via `springdoc.paths-to-exclude`

---

## [2.0.0] — 2026-04-03: Spring Boot 4 + Spring AI 2 Migration

Major version upgrade of the entire workshop from Spring Boot 3.5.6 / Spring AI 1.0.3 to Spring Boot 4.0.5 / Spring AI 2.0.0-M4.

### Tech Stack

| Component | Before | After |
|-----------|--------|-------|
| Spring Boot | 3.5.6 | **4.0.5** |
| Spring AI | 1.0.3 | **2.0.0-M4** |
| Spring Framework | 6.2.x | **7.x** |
| Java | 21 | **25** |
| Maven | 3.9.9 | **3.9.14** |
| Spring Cloud | 2025.0.0 | **2025.1.1** |
| Spring Cloud Azure | 6.0.0 | **7.1.0** |
| Spring Shell | 3.4.1 | **4.0.1** |
| Jackson | 2.x | **3.0** (databind: `tools.jackson`, annotations: `com.fasterxml.jackson`) |
| Flyway | 10.x | **11.11** |
| Micrometer | 1.14.x | **1.16** |
| PostgreSQL (Docker) | pgvector:pg17 | **pgvector:pg18** |
| pgAdmin (Docker) | 9.8.0 | **latest** |
| Observability | 6 containers (Prometheus/Grafana/Tempo/Loki/OTel/MailDev) | **grafana/otel-lgtm:latest** + MailDev |

### Ollama Models

| Model | Before | After | Reason |
|-------|--------|-------|--------|
| Chat | llama3.2 (3B) | **qwen3 (8B)** | Reliable structured output + tool calling; Mistral 7B had weak tool-call compliance |
| Embedding | mxbai-embed-large (512 ctx) | **nomic-embed-text (8192 ctx)** | Bike documents exceed 512 token context |
| Multimodal | llava (manual switch) | **llava (auto-switch)** | Controller detects Ollama and switches model |

### New Features

#### Distributed Tracing Module (`components/patterns/04-distributed-tracing/`)
- Custom AOP annotations: `@TracedEndpoint`, `@TracedService`, `@TracedRepository`
- Three ordered aspects creating proper span hierarchy (Controller → Service → Repository)
- OpenTelemetry Tracer, ObservedAspect, Logback OTel appender config
- All 24 REST controllers annotated with `@TracedEndpoint`

#### LGTM Observability Stack
- Single `grafana/otel-lgtm:latest` container replaces 6 separate containers
- Includes: Grafana, Loki (logs), Tempo (traces), Mimir (metrics), OTel Collector
- Custom dashboard provisioning with default dashboard suppression
- Traces, metrics, and logs all flow via OTLP

#### Spring AI Workshop Overview Dashboard
- New Grafana dashboard replacing the old Prometheus Stats dashboard
- Panels: Application, Uptime, Start Time, Live Threads, CPU Usage, Heap Memory
- HTTP Request Rate and Response Time (p95) by URI
- JVM Heap Memory, CPU & System Load, HikariCP Connections
- GC Pause Duration, Log Events per minute (ERROR/WARN/INFO)

### Breaking Changes Resolved

#### Spring Boot 4
- **Jackson 3**: `com.fasterxml.jackson.databind` → `tools.jackson.databind` (annotations unchanged)
- **Flyway**: `flyway-core` → `spring-boot-starter-flyway`
- **Spring Cloud Gateway 5**: `spring-cloud-starter-gateway-mvc` → `spring-cloud-starter-gateway-server-webmvc`, `HandlerFunctions.http(url)` → `http()` + `uri()` filter
- **Spring Shell 4**: `@CommandScan` → `@EnableCommand`, `@Command(command=)` → `@Command(name=)`, `PromptProvider` removed
- **AutoConfiguration packages moved**: `o.s.b.autoconfigure.jdbc` → `o.s.b.jdbc.autoconfigure`, `o.s.b.autoconfigure.flyway` → `o.s.b.flyway.autoconfigure`
- **Micrometer 1.16 metric names**: `_seconds` → `_milliseconds` throughout
- **`spring-boot-starter-aop` removed**: explicit `spring-aop` + `aspectjweaver` dependencies needed
- **`@MockBean` → `@MockitoBean`**, `@SpyBean` → `@MockitoSpyBean`

#### Spring AI 2.0
- **MCP SSE → Streamable HTTP**: `spring-ai-starter-mcp-server-webflux` → `webmvc`, `WebFluxSseClientTransport` → `HttpClientStreamableHttpTransport`
- **MCP annotations**: `com.logaritex.mcp.annotation` → `org.springframework.ai.mcp.annotation`
- **`SpringAiMcpAnnotationProvider`** → `SyncMcpAnnotationProviders` (different API: `resourceSpecifications()`, `promptSpecifications()`, `completeSpecifications()`)
- **`McpSyncClientCustomizer`** → `McpClientCustomizer<B>` (generic)
- **Google provider**: `spring-ai-starter-model-vertex-ai-gemini` → `spring-ai-starter-model-google-genai`
- **Deprecated `functions` config**: `spring.ai.openai.chat.options.functions` removed — tools registered inline via `.tools()`
- **`StdioClientTransport`** now requires `McpJsonMapper` parameter
- **MCP bean name conflicts**: Spring AI 2.0 auto-config creates `resourceSpecs`/`promptSpecs`/`completionSpecs` beans — manual beans need unique names
- **`LocalDate`/`LocalTime` in tool params**: Jackson 3 can't deserialize — use `String` instead
- **`returnDirect=true` + `entity()`**: incompatible in Spring AI 2.0 — use `.content()` with manual JSON parsing

### Fixes Applied

#### Embedding & Vector Store
- Switched default embedding model to `nomic-embed-text` (8192 token context vs 512, **768 dimensions**)
- pgvector dimension changed from 1024 → **768** in `application.yaml`
- Added `TokenTextSplitter` chunking before `vectorStore.add()` in vector store and RAG controllers
- Result: 25 bike documents → 72 chunks, all load and query successfully
- **Note:** If upgrading from an existing database with 1024-dimension vectors, drop the `vector_store` table before starting (Spring AI recreates it automatically)

#### Chat Endpoints
- Switched default chat model to `qwen3` (8B) — reliable structured output (POJO/Map), tool calling, and reasoning
- Fixed `chat_04/map` prompt to explicitly request JSON object structure
- Fixed `chat_05/search`: `LocalDate` → `String` params, `.content()` + manual JSON parsing for `returnDirect`
- Fixed `chat_07/explain`: auto-switches to `llava` model when running on Ollama

#### Observability
- Created `logback-spring.xml` with OTel Logback appender for both provider apps
- Fixed `management.tracing.export.enabled` → `management.tracing.enabled` (correct property for Spring Boot 4)
- Added `logging.level.com.example.tracing: DEBUG` for tracing aspect logs
- All Grafana dashboards updated for Micrometer 1.16 metric names (`_seconds` → `_milliseconds`)
- Fixed PromQL syntax: `metric/1000{labels}` → `metric{labels}/1000`
- Replaced Tomcat thread metrics with JVM thread metrics (Tomcat metrics not available via OTLP)
- Added `or vector(0)` fallback for error count panels (show 0 instead of N/A)

#### MCP
- Migrated 3 MCP modules from SSE to Streamable HTTP transport
- Updated MCP annotations from external `com.logaritex.mcp` to Spring AI built-in
- Fixed `StdioClientTransport` constructor for MCP SDK 1.1

#### Infrastructure
- Created sample `Profile.pdf` for chain-of-thought and self-reflection demos
- Replaced `check-deps.sh` and `download-deps.sh` with unified `workshop.sh` (see [2.1.0] below)
- Cleaned up 11 obsolete observability config files

### Test Results

| Provider | Pass | Total | Notes |
|----------|:----:|:-----:|-------|
| **Ollama** (qwen3 + nomic-embed-text) | 44 | 44 | All chat + embedding + vector + patterns + agents |
| **OpenAI** (gpt-4o-mini) | 44 | 44 | All endpoints |
| **Anthropic** (Claude, direct API) | 14 | 14 | All chat endpoints (no embeddings — Anthropic doesn't offer them) |
| **AWS Bedrock** (Amazon Nova Lite, eu-central-1) | 8 | 8 | Chat + stuff-the-prompt (no embeddings — Converse starter is chat-only) |
| **Google** (Gemini 2.5 Flash) | 13 | 13 | All chat endpoints (dependency conflicts fixed, API key mode) |
| **Azure OpenAI** (gpt-4.1-mini, East US) | 8 | 8 | All chat endpoints pass (Standard SKU with 1 TPM) |

### Documentation

- `migration/flow.md` — Complete workshop demo flow with all 8 stages and endpoints
- `migration/prerequisites.md` — Local setup requirements (JDK 25, Docker, Ollama, API keys)
- `migration/upgrade.md` — Step-by-step migration plan (9 phases)
- `migration/upgrade_status.md` — All findings and deviations from plan
- `migration/test_plan.md` — 10-phase test plan
- `migration/test_results.md` — Detailed test results per endpoint
- `migration/model_mapping.md` — Provider compatibility matrix (52 endpoints)
- `CLAUDE.md` — Project context for AI assistants
- All 14 README files updated for new tech stack
- New `Spring AI Workshop Overview` Grafana dashboard replacing Prometheus Stats
