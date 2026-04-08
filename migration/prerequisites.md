# Prerequisites — Spring AI Zero-to-Hero Workshop

Everything you need to run the workshop locally after the migration to Spring Boot 4.0.5 + Spring AI 2.0.0-M4.

---

## JDK 25

Spring Boot 4.0 requires **Java 25** as minimum version.

### Install via SDKMAN (recommended)

```bash
sdk install java 25.0.2-librca
sdk use java 25.0.2-librca
```

### Install via Homebrew (macOS)

```bash
brew install openjdk@25
export JAVA_HOME=$(/usr/libexec/java_home -v 25)
```

### Verify

```bash
java --version
# Expected: openjdk 25 ...
```

Ensure `JAVA_HOME` is set in your shell profile (`~/.zshrc` or `~/.bashrc`).

---

## Maven 3.9.14

The project uses Maven Wrapper (`.mvn/wrapper/`). After migration, the wrapper is configured for Maven 3.9.14.

### Using the wrapper (no install needed)

```bash
./mvnw --version
# Should show Apache Maven 3.9.14
```

### Global install (optional)

```bash
sdk install maven 3.9.14
# or
brew install maven
```

---

## Docker & Docker Compose

Required for PostgreSQL/pgvector and the observability (LGTM) stack.

### Install

- **macOS**: [Docker Desktop](https://www.docker.com/products/docker-desktop/) or [Colima](https://github.com/abiosoft/colima)
- **Linux**: Docker Engine + Docker Compose plugin

### Verify

```bash
docker --version
docker compose version
```

### Resource Allocation

Recommended Docker resources:
- **CPU**: 4+ cores
- **Memory**: 8GB minimum (16GB recommended when running Ollama + Docker simultaneously)
- **Disk**: 20GB for images and volumes

---

## Ollama (Local AI Models)

Ollama runs AI models locally — no API keys needed. Required for the `provider-ollama` application.

### Install

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh
```

### Start Ollama

```bash
ollama serve
# Runs on http://localhost:11434/
```

### Pull Required Models

```bash
# Required (core demos)
ollama pull qwen3               # Chat model (8B, 5.2GB) — default for provider-ollama
ollama pull nomic-embed-text    # Embedding model (768 dims, 8192 ctx, ~274MB) — default for provider-ollama

# Optional (additional demos)
ollama pull llava               # Multimodal model — image+text (chat_07 demo)
ollama pull mxbai-embed-large   # Alternative embedding model (1024 dims, 512 ctx — for short texts only)
```

### Verify

```bash
ollama list
# Should show qwen3 and nomic-embed-text

curl http://localhost:11434/api/tags
# Should return JSON with model list
```

### System Requirements for Ollama

| Model | RAM Required | Disk |
|-------|-------------|------|
| qwen3 (8B) | ~8GB | ~5.2GB |
| mxbai-embed-large | ~2GB | ~670MB |
| llava (7B) | ~8GB | ~4.7GB |
| llama3.2 (3B) | ~4GB | ~2.0GB |

**Minimum**: 8GB RAM for qwen3 + nomic-embed-text
**Recommended**: 16GB RAM for running all models

---

## PostgreSQL with pgvector

Vector database for storing and searching embeddings. Runs via Docker.

### Start

```bash
docker compose -f docker/postgres/docker-compose.yaml up -d
```

### Details

| Service | Port | Credentials |
|---------|------|------------|
| PostgreSQL 18 (pgvector) | 15432 | postgres / password |
| pgAdmin | 15433 | admin@example.com / admin |

### Databases

The init script (`docker/postgres/db/docker_postgres_init.sql`) creates three databases:
- `openai` — for provider-openai
- `azure` — for provider-azure
- `ollama` — for provider-ollama

Each database has the pgvector extension available automatically via the `pgvector/pgvector:pg18` image.

### Verify

```bash
# Check container is running
docker ps | grep postgres

# Test connection
psql -h localhost -p 15432 -U postgres -d ollama -c "SELECT 1;"
# Password: password

# Verify pgvector extension
psql -h localhost -p 15432 -U postgres -d ollama -c "CREATE EXTENSION IF NOT EXISTS vector; SELECT extversion FROM pg_extension WHERE extname='vector';"
```

### pgAdmin

Open http://localhost:15433 in your browser. The PostgreSQL server connection is pre-configured via `docker_pgadmin_servers.json`.

### Important: Vector Store Dimension

The Ollama provider uses `nomic-embed-text` which produces **768-dimension** embeddings. The pgvector table must match this dimension. If you previously used a different embedding model (e.g., `mxbai-embed-large` with 1024 dimensions), you must reset the vector store table:

```bash
docker exec postgres-postgres-1 psql -U postgres -d ollama -c "DROP TABLE IF EXISTS vector_store CASCADE;"
```

Spring AI will automatically recreate the table with the correct dimension (768) on next startup. Without this reset, vector store load endpoints will fail with a dimension mismatch error.

---

## Observability Stack — Grafana LGTM

All-in-one observability with Grafana, Loki (logs), Tempo (traces), Mimir (metrics), and OTel Collector.

### Start

```bash
docker compose -f docker/observability-stack/docker-compose.yaml up -d
```

### Services

| Service | Port | Purpose |
|---------|------|---------|
| Grafana | 3000 | Dashboards, trace viewer, log explorer |
| OTLP gRPC | 4317 | Telemetry ingestion (gRPC) |
| OTLP HTTP | 4318 | Telemetry ingestion (HTTP) |
| MailDev Web UI | 1080 | Email testing interface |
| MailDev SMTP | 1025 | SMTP server for test emails |

### Access Grafana

Open http://localhost:3000 — anonymous admin access enabled, no login required.

Pre-provisioned dashboards:
- **JVM Micrometer** — JVM memory, GC, threads, CPU
- **Spring Boot Microservices** — Application metrics overview
- **HikariCP / JDBC** — Connection pool monitoring
- **Prometheus Stats** — Prometheus self-monitoring

### How Telemetry Flows

```
Spring Boot App
  ├── Traces  → OTLP HTTP (:4318/v1/traces)  → OTel Collector → Tempo
  ├── Metrics → OTLP HTTP (:4318/v1/metrics)  → OTel Collector → Mimir
  └── Logs    → OTLP HTTP (:4318/v1/logs)     → OTel Collector → Loki
                                                        ↓
                                                    Grafana (:3000)
```

### Verify

```bash
# Check LGTM is healthy
curl -sf http://localhost:3000/api/health
# Expected: {"commit":"...","database":"ok","version":"..."}

# Check OTLP endpoint is accepting data
curl -sf http://localhost:4318/v1/traces -X POST -H "Content-Type: application/json" -d '{}'
# Should not return connection refused
```

---

## API Keys (Cloud Providers)

API keys are required only for cloud-based providers. They are **not needed** for the Ollama provider (fully local).

### Configuration

Create `src/main/resources/creds.yaml` in the relevant provider application (this file is gitignored):

#### OpenAI (`applications/provider-openai/src/main/resources/creds.yaml`)

```yaml
spring:
  ai:
    openai:
      api-key: sk-...your-key...
```

#### Anthropic (`applications/provider-anthropic/src/main/resources/creds.yaml`)

```yaml
spring:
  ai:
    anthropic:
      api-key: sk-ant-...your-key...
```

#### Azure OpenAI (`applications/provider-azure/src/main/resources/creds.yaml`)

```yaml
spring:
  ai:
    azure:
      openai:
        api-key: ...your-key...
        endpoint: https://your-resource.openai.azure.com/
```

#### Google Vertex AI (`applications/provider-google/src/main/resources/creds.yaml`)

```yaml
spring:
  ai:
    google:
      genai:
        project-id: your-gcp-project
        location: us-central1
        # Or use API key mode:
        # api-key: ...your-key...
```

#### AWS Bedrock (`applications/provider-aws/`)

Uses AWS CLI credentials. Configure via:

```bash
aws configure
# Or set environment variables:
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1
```

---

## IDE Setup

### IntelliJ IDEA

- Version: 2025.1 or later (Spring Boot 4 support)
- SDK: JDK 25
- Maven: Use bundled or 3.9.14
- Import as Maven project from root `pom.xml`
- Enable annotation processing (for Lombok if used)

### VS Code

- Extensions: Extension Pack for Java, Spring Boot Extension Pack
- Set `java.configuration.runtimes` to point to JDK 25
- Maven for Java extension handles multi-module builds

---

## Quick Start Checklist

```
[ ] JDK 25 installed and JAVA_HOME set
[ ] Maven 3.9.14 available (via wrapper or global)
[ ] Docker running with sufficient resources (8GB+ RAM)
[ ] Ollama installed and serving
[ ] ollama pull qwen3               # Chat model (8B, 5.2GB) — default for provider-ollama
[ ] ollama pull nomic-embed-text
[ ] docker compose -f docker/postgres/docker-compose.yaml up -d
[ ] docker compose -f docker/observability-stack/docker-compose.yaml up -d
[ ] Grafana accessible at http://localhost:3000
[ ] (Optional) API keys configured in creds.yaml for cloud providers
```

### Smoke Test

```bash
# Build everything
./mvnw clean compile

# Run Ollama provider with pgvector and observation
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation

# Test a chat endpoint
curl "http://localhost:8080/chat/01/joke?topic=spring"

# Check traces in Grafana
open http://localhost:3000  # Navigate to Explore → Tempo
```
