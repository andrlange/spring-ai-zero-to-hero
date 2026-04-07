# Quickstart — Workshop Attendee Guide

Get from zero to your first AI call in 5 minutes. This guide assumes you are in a live workshop session where Ollama models may already be downloaded.

---

## 1. Prerequisites

Check that you have these installed before the workshop starts:

```
[ ] Java 25 — java --version should show openjdk 25
[ ] Maven wrapper — ./mvnw --version should show 3.9.14
[ ] Docker — docker --version and docker compose version
[ ] Ollama — ollama --version
```

**Java 25 via SDKMAN:**

```bash
sdk install java 25.0.2-librca
sdk use java 25.0.2-librca
```

**Java 25 via Homebrew (macOS):**

```bash
brew install openjdk@25
export JAVA_HOME=$(/usr/libexec/java_home -v 25)
```

If any of these are missing, see [Provider Setup](providers.md) for detailed installation instructions.

---

## 2. Check your environment

```bash
./workshop.sh check
```

This verifies Java, Docker, Ollama, and required models are all ready.

---

## 3. Set up infrastructure

```bash
./workshop.sh setup
```

This starts PostgreSQL with pgvector and the Grafana observability stack via Docker Compose. Both run in the background.

Verify:

```bash
docker ps
# Should show: postgres, grafana/otel-lgtm containers running
```

---

## 4. Start the workshop app

```bash
./workshop.sh start ollama --profiles pgvector,ui
```

This runs the Ollama provider application with persistent vector storage and the workshop dashboard UI. The app starts on port 8080.

Wait for the startup log line: `Started ProviderOllamaApplication in ...`

If you prefer running manually:

```bash
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation
```

---

## 5. Open the dashboard

http://localhost:8080/dashboard

The dashboard shows all available endpoints organized by stage. Use it to explore and trigger demos.

---

## 6. Try your first endpoint

```bash
curl "http://localhost:8080/chat/01/joke?topic=spring"
```

You should get a short AI-generated joke about Spring. This uses the simplest possible API: `chatModel.call(String)`.

---

## 7. Quick tour of key demos

Work through these in order — each builds on the previous concept.

### Chat basics

```bash
# Simplest call
curl "http://localhost:8080/chat/01/joke?topic=spring"

# Fluent ChatClient API
curl "http://localhost:8080/chat/02/client/joke?topic=java"

# Structured output — returns a Java array of records
curl "http://localhost:8080/chat/04/plays/object"

# Tool calling — AI calls your Java method to get current time
curl "http://localhost:8080/chat/05/time?tz=Europe/Berlin"

# Streaming response (server-sent events)
curl "http://localhost:8080/chat/08/essay?topic=spring"
```

### Embeddings and vector search

```bash
# Check embedding dimensions (768 for nomic-embed-text)
curl "http://localhost:8080/embed/01/dimension"

# Cosine similarity between word pairs
curl "http://localhost:8080/embed/02/words"
```

### RAG — load data, then query

```bash
# Step 1: load bike documents into the vector store
curl "http://localhost:8080/rag/01/load"

# Step 2: ask a question — AI answers from the loaded docs
curl "http://localhost:8080/rag/01/query?topic=mountain+bike"
```

### Observability

Start with the `observation` profile (or add it alongside pgvector):

```bash
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation
```

Then open Grafana at http://localhost:3000 and navigate to Explore > Tempo to see traces from your API calls.

---

## Next steps

Once you are comfortable with the basics, follow the [Full Guide](guide.md) for all 8 stages including MCP, agentic systems, and the observability walkthrough.

For cloud providers or embedding model setup, see [Provider Setup](providers.md).
