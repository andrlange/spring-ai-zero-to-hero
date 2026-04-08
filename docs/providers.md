# Provider Setup

How to configure each AI provider, what credentials are needed, and which demos work with which provider.

---

## Provider Comparison

| Provider | Chat | Embedding | Multimodal | Tool Calling | Local | Cost |
|----------|:----:|:---------:|:----------:|:------------:|:-----:|------|
| **Ollama** | qwen3 (8B) | nomic-embed-text | llava (auto) | Yes | Yes | Free |
| **OpenAI** | gpt-4o-mini | text-embedding-3 | gpt-4o | Yes | No | Pay-per-use |
| **Anthropic** | Claude | — | Claude 3+ | Yes | No | Pay-per-use |
| **Azure OpenAI** | gpt-4.1-mini | text-embedding-3 | gpt-4o | Yes | No | Enterprise |
| **Google** | Gemini 2.5 Flash | text-embedding-004 | Gemini | Yes | No | Pay-per-use |
| **AWS Bedrock** | Amazon Nova Lite | — | — | Yes | No | Enterprise |

### Choosing a provider

| Use case | Recommended provider | Why |
|----------|---------------------|-----|
| Workshop / Offline | Ollama | Free, no API keys, all 44 demos work |
| Full feature demos | OpenAI | Chat + image + audio + multimodal + tools |
| Best reasoning | Anthropic or OpenAI | Claude / GPT-4o for complex tasks |
| Enterprise / Compliance | Azure OpenAI or AWS Bedrock | Data residency, SLAs, corporate billing |
| Cost-conscious | Ollama or OpenAI gpt-4o-mini | Free (local) or very cheap (cloud) |
| Google Cloud users | Google Vertex AI / GenAI | Native GCP integration |

---

## Provider Compatibility Matrix

Verified 2026-04-03.

| Stage | Endpoints | Ollama | OpenAI | Anthropic | AWS Bedrock | Google | Azure |
|-------|:---------:|:------:|:------:|:---------:|:-----------:|:------:|:-----:|
| 1. Chat | 14 | 14/14 | 14/14 | 14/14 | 7/14 | 13/13 | 7/8 |
| 2. Embeddings | 10 | 10/10 | 10/10 | N/A | N/A | 13/13 | 7/8 |
| 3. Vector Stores | 2 | 2/2 | 2/2 | N/A | N/A | 13/13 | 7/8 |
| 4. Patterns | 7 | 7/7 | 7/7 | N/A | 1 (stuffit) | 13/13 | 7/8 |
| 5. Agents | 4 | 4/4 | 4/4 | N/A | N/A | 13/13 | 7/8 |
| 6. MCP | 6 | 6/6 | 6/6 | N/A | N/A | 13/13 | 7/8 |
| 7. Agentic | 4 | 2 (CLIs) | 4/4 | N/A | N/A | 13/13 | 7/8 |
| 8. Observability | 5 | 5/5 | 5/5 | N/A | N/A | 13/13 | 7/8 |
| **Total** | **52** | **50/52** | **52/52** | **14/14** | **8/8** | **13/13** | **8/8** |

**Notes:**
- **Anthropic:** No embedding API — stages 2-8 not applicable. All 14 chat endpoints pass.
- **AWS Bedrock:** Amazon Nova Lite (eu-central-1). The Converse starter is chat-only (no `EmbeddingModel` auto-config). Anthropic models on Bedrock require a use-case form.
- **Google:** 13/13 PASS with gemini-2.5-flash. Requires protobuf and okhttp version overrides in pom.xml (already applied).
- **Azure:** 8/8 PASS with gpt-4.1-mini in East US. Standard SKU required (not GlobalStandard).
- **Ollama:** 50/52 — agentic agent REST apps (Stage 7) require OpenAI (`OpenAiChatOptions`). Agentic CLIs work with any provider.

---

## Ollama (Local, No API Key — Optional)

### System requirements

| Model | Purpose | Parameters | RAM | Disk | Context |
|-------|---------|-----------|-----|------|---------|
| `qwen3` | Chat (default) | 8B | ~8 GB | 5.2 GB | 32k |
| `nomic-embed-text` | Embeddings (default) | 137M | ~1 GB | 274 MB | 8192 |
| `llava` | Multimodal — auto-used for chat_07 | 7B | ~8 GB | 4.7 GB | 4096 |
| `llama3.2` | Optional: faster chat for simple demos | 3B | ~4 GB | 2.0 GB | 128k |

**16 GB macOS:** `qwen3` + `nomic-embed-text` runs at ~10 GB active. `llava` loads on-demand for chat_07 only.

**Minimum system:** 8 GB RAM for qwen3 + nomic-embed-text. 16 GB recommended for running all models.

### Install and start

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama
ollama serve   # runs on http://localhost:11434/

# Pull required models
ollama pull qwen3
ollama pull nomic-embed-text

# Optional
ollama pull llava        # multimodal (chat_07)
ollama pull llama3.2     # faster chat for simple demos
```

### Verify

```bash
ollama list
curl http://localhost:11434/api/tags
```

No `creds.yaml` needed — Ollama is fully local.

---

## OpenAI

Supports all 52 endpoints. Recommended for the full workshop experience.

### creds.yaml

File location: `applications/provider-openai/src/main/resources/creds.yaml` (gitignored)

```yaml
spring:
  ai:
    openai:
      api-key: sk-...your-key...
```

### Run

```bash
./mvnw spring-boot:run -pl applications/provider-openai \
  -Dspring-boot.run.profiles=pgvector,observation
```

---

## Anthropic

Supports all 14 chat endpoints. No embedding or vector store demos (no embedding API).

### creds.yaml

File location: `applications/provider-anthropic/src/main/resources/creds.yaml`

```yaml
spring:
  ai:
    anthropic:
      api-key: sk-ant-...your-key...
```

### Run

```bash
./mvnw spring-boot:run -pl applications/provider-anthropic \
  -Dspring-boot.run.profiles=observation
```

---

## Azure OpenAI

Supports chat, embeddings, tool calling. Requires Standard SKU (not GlobalStandard).

### creds.yaml

File location: `applications/provider-azure/src/main/resources/creds.yaml`

```yaml
spring:
  ai:
    azure:
      openai:
        api-key: ...your-key...
        endpoint: https://your-resource.openai.azure.com/
```

### Run

```bash
./mvnw spring-boot:run -pl applications/provider-azure \
  -Dspring-boot.run.profiles=pgvector,observation
```

---

## Google (Gemini / Vertex AI)

Supports chat, embeddings, tool calling. Requires API key or GCP service account.

### creds.yaml

File location: `applications/provider-google/src/main/resources/creds.yaml`

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

### Run

```bash
./mvnw spring-boot:run -pl applications/provider-google \
  -Dspring-boot.run.profiles=pgvector,observation
```

---

## AWS Bedrock

Chat-only provider (no EmbeddingModel auto-config). Amazon Nova Lite works without any approval form. Anthropic models on Bedrock require submitting a use-case form.

### Credentials

Uses AWS CLI credentials — no `creds.yaml`:

```bash
aws configure
# or set environment variables:
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=eu-central-1
```

### Run

```bash
./mvnw spring-boot:run -pl applications/provider-aws \
  -Dspring-boot.run.profiles=observation
```

---

## Docker Infrastructure

### PostgreSQL with pgvector

Required for the `pgvector` profile.

```bash
docker compose -f docker/postgres/docker-compose.yaml up -d
```

| Service | Port | Credentials |
|---------|------|------------|
| PostgreSQL 18 (pgvector) | 15432 | postgres / password |
| pgAdmin | 15433 | admin@example.com / admin |

Databases pre-created by init script: `openai`, `azure`, `ollama`

### Observability stack (LGTM)

Required for the `observation` profile.

```bash
docker compose -f docker/observability-stack/docker-compose.yaml up -d
```

| Service | Port | Purpose |
|---------|------|---------|
| Grafana | 3000 | Dashboards, trace viewer, log explorer |
| OTLP gRPC | 4317 | Telemetry ingestion (gRPC) |
| OTLP HTTP | 4318 | Telemetry ingestion (HTTP) |
| MailDev Web UI | 1080 | Email testing interface |
| MailDev SMTP | 1025 | SMTP server for test emails |

### Docker resource allocation

Recommended Docker Desktop settings:

- CPU: 4+ cores
- Memory: 8 GB minimum (16 GB recommended when running Ollama + Docker simultaneously)
- Disk: 20 GB for images and volumes

---

## IDE Setup

### IntelliJ IDEA

- Version: 2025.1 or later (Spring Boot 4 support)
- SDK: JDK 25
- Import as Maven project from root `pom.xml`
- Maven: bundled or 3.9.14

### VS Code

- Extensions: Extension Pack for Java, Spring Boot Extension Pack
- Set `java.configuration.runtimes` to point to JDK 25
- Maven for Java extension handles multi-module builds
