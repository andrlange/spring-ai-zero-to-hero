# OpenAI

**Spring Boot 4.0.6 | Spring AI 2.0.0-M8 | spring-ai-starter-model-openai**

To run the sample application you will need an OpenAI API key.

## Setup

Copy `src/main/resources/creds-template.yaml` to `src/main/resources/creds.yaml` and add your key:

```yaml
spring:
  ai:
    openai:
      api-key: sk-...your-key...
```

Get a key at [platform.openai.com/api-keys](https://platform.openai.com/api-keys).

## Run

```bash
./mvnw spring-boot:run -pl applications/provider-openai -Dspring-boot.run.profiles=pgvector,observation
```

Or run from the IDE for breakpoints.

## Models

- **Chat:** gpt-4o-mini (default)
- **Embeddings:** text-embedding-3-small (1536 dims)
- **Image:** DALL-E 3
- **Audio:** Whisper
- **Multimodal:** gpt-4o

All 44 workshop endpoints pass with OpenAI.
