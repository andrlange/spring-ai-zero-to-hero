# Anthropic

**Spring Boot 4.1.1 | Spring AI 2.0.1 | spring-ai-starter-model-anthropic**

To run the sample application you will need an Anthropic API key.

## Setup

Copy `src/main/resources/creds-template.yaml` to `src/main/resources/creds.yaml` and add your key:

```yaml
spring:
  ai:
    anthropic:
      api-key: sk-ant-...your-key...
```

## Run

```bash
./mvnw spring-boot:run -pl applications/provider-anthropic
```

Or run from the IDE for breakpoints.

## Models

- **Chat:** Claude 3.5 Sonnet / Claude 4 (depending on your plan)
- **Tool calling:** Yes (Claude 3+)
- **Multimodal:** Yes (Claude 3+, image input)

## Anthropic Does Not Offer Embedding Models

From the [docs](https://docs.anthropic.com/en/docs/build-with-claude/embeddings):

> Anthropic does not offer its own embedding model. One embeddings provider that has a wide variety of options and capabilities is Voyage AI.

Embedding-dependent demos (vector stores, RAG) require a separate embedding provider or won't work with Anthropic alone.
