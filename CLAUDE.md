# CLAUDE.md — spring-ai-zero-to-hero

## Project Overview

Multi-module Maven workshop project demonstrating Spring AI capabilities: chat, embeddings, vector stores, RAG, MCP (Model Context Protocol), agentic patterns across 6 AI providers.

## Tech Stack (Current → Target Migration)

| Component | Current | Target |
|-----------|---------|--------|
| Spring Boot | 3.5.6 | 4.0.5 |
| Spring AI | 1.0.3 | 2.0.0-M4 |
| Spring Framework | 6.x | 7.x |
| Java | 21 | 25 |
| Maven | 3.9.9 (wrapper) | 3.9.14 |

## Project Structure

```
spring-ai-zero-to-hero/
├── applications/              # Provider-specific Spring Boot apps
│   ├── provider-openai/       # OpenAI (gpt-4o-mini)
│   ├── provider-anthropic/    # Anthropic (Claude)
│   ├── provider-azure/        # Azure OpenAI
│   ├── provider-google/       # Google Vertex AI / Gemini
│   ├── provider-aws/          # AWS Bedrock
│   ├── provider-ollama/       # Ollama (local: llama3.2, mxbai-embed-large)
│   └── gateway/               # Spring Cloud Gateway MVC (spy/audit)
├── components/
│   ├── apis/                  # API demos (chat, embedding, vector-store, audio, image)
│   ├── patterns/              # AI patterns (stuff-prompt, RAG, chat-memory, CoT, reflection)
│   ├── config-pgvector/       # PgVector auto-config (profile-based)
│   └── data/                  # Shared datasets (bikes, customers, products, orders)
├── mcp/                       # Model Context Protocol demos — runnable from /dashboard/stage/6
│   ├── 01-mcp-stdio-server/   # Weather tools via stdio (subprocess)
│   ├── 02-mcp-http-server/    # Weather tools via Streamable HTTP :8081
│   ├── 03-mcp-client/         # ChatClient + MCP client (local or mcp-external profile)
│   ├── 04-dynamic-tool-calling/  # Runtime tool registration — server :8082 + client
│   └── 05-mcp-capabilities/   # Tools + resources + prompts + completions :8083
├── agentic-system/            # Agentic patterns (inner-monologue, model-directed-loop)
├── docker/
│   ├── postgres/              # PostgreSQL + pgvector + pgAdmin
│   └── observability-stack/   # Grafana + Loki + Tempo + OTel Collector + Prometheus
└── migration/                 # Migration plans and docs (being created)
```

## Build & Run

```bash
# Build all modules
./mvnw clean verify

# Run a specific provider (e.g., Ollama with pgvector)
./mvnw spring-boot:run -pl applications/provider-ollama -Dspring-boot.run.profiles=pgvector,observation

# Start infrastructure
docker compose -f docker/postgres/docker-compose.yaml up -d
docker compose -f docker/observability-stack/docker-compose.yaml up -d
```

## Spring Profiles

- `pgvector` — Use PostgreSQL pgvector instead of in-memory SimpleVectorStore
- `spy` — Route API calls through gateway at :7777 for inspection
- `observation` — Enable full observability (traces, metrics, logs)

## Code Style

- Google Java Format enforced by Spotless (runs at compile phase)
- Run `./mvnw spotless:apply` to auto-format before committing

## Key Conventions

- Provider apps compose component modules via Maven dependencies
- AI provider abstraction: same component code works with any provider
- Vector store abstraction: SimpleVectorStore (default) or PgVectorStore (pgvector profile)
- API keys loaded via `spring.config.import: optional:classpath:/creds.yaml` (not committed)
- All REST endpoints follow pattern: `/category/number/action` (e.g., `/chat/02/client/joke`)

## Dependencies of Note

- `spring-ai-bom` manages all Spring AI versions centrally in root pom.xml
- `spring-cloud-dependencies` for Gateway
- `spring-shell-dependencies` for agentic CLI modules
- `com.logaritex.mcp:spring-ai-mcp-annotations:0.1.0` in mcp/05 (to be migrated to Spring AI 2.0 built-in)

## Docker Infrastructure

- **PostgreSQL**: pgvector/pgvector:pg17, port 15432, databases: openai, azure, ollama
- **pgAdmin**: port 15433, admin@example.com/admin
- **Grafana**: port 3000
- **Prometheus**: port 9090, scrapes /actuator/prometheus
- **Tempo**: port 9411 (Zipkin), 3200 (OTLP)
- **OTel Collector**: ports 4317 (gRPC), 4318 (HTTP)
- **Loki**: port 3100
- **MailDev**: port 1080 (Web UI), 1025 (SMTP)

## Migration Context

Active migration planned to Spring Boot 4.0.5 + Spring AI 2.0.0-M4. See `migration/` folder for plans. Key changes:
- MCP SSE transport → Streamable HTTP (3 modules affected)
- MCP annotations: `com.logaritex.mcp.*` → `org.springframework.ai.mcp.annotation.*`
- Flyway: `flyway-core` → `spring-boot-starter-flyway`
- Observability: Brave/Zipkin → spring-boot-starter-opentelemetry + LGTM stack
- Distributed tracing pattern: @TracedEndpoint/@TracedService/@TracedRepository

