# Google GenAI (Gemini)

**Spring Boot 4.0.6 | Spring AI 2.0.0-M8 | spring-ai-starter-model-google-genai**

All 13 chat endpoints pass with Gemini 2.5 Flash.

## Setup: Gemini API Key (recommended)

1. Go to https://aistudio.google.com/apikey and create a key
2. Copy `src/main/resources/creds-template.yaml` to `src/main/resources/creds.yaml`:

```yaml
spring:
  ai:
    google:
      genai:
        api-key: your-api-key
        project-id: your-project-id
        chat:
          options:
            model: gemini-2.5-flash
        embedding:
          api-key: your-api-key
          project-id: your-project-id
          text:
            options:
              model: text-embedding-004
```

**Note:** Embedding requires its own `api-key` under `spring.ai.google.genai.embedding.*`.

## Run

```bash
./mvnw spring-boot:run -pl applications/provider-google
```

## Models

- **Chat:** Gemini 2.5 Flash (default)
- **Embeddings:** text-embedding-004 (requires separate config)
- **Multimodal:** Gemini (image + text)
- **Tool calling:** Yes

## Dependency Overrides

This provider requires explicit dependency overrides for Spring Boot 4 compatibility:
- `protobuf-java` 4.32.0 (Google AI SDK ships 3.x)
- `okhttp-jvm` 5.2.1 + `okio-jvm` 3.16.1 (excludes old okhttp 4.x from SDK)

These are configured in `pom.xml`.

**Note:** Starter artifact renamed in Spring AI 2.0: `vertex-ai-gemini` -> `google-genai`
