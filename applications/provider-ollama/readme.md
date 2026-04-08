# Ollama (Local)

**Spring Boot 4.0.5 | Spring AI 2.0.0-M4 | spring-ai-starter-model-ollama**

Runs entirely locally with no API keys needed.

## Setup

Install [Ollama](https://ollama.com/) and pull the required models:

```bash
ollama pull qwen3               # Chat model (8B, default) — reliable tool calling + structured output
ollama pull nomic-embed-text    # Embedding model (768 dims, 8192 ctx)
ollama pull llava               # Multimodal model (auto-used for chat_07)
```

Start Ollama: `ollama serve`

## Run

```bash
./mvnw spring-boot:run -pl applications/provider-ollama \
  -Dspring-boot.run.profiles=pgvector,observation
```

Models are configured in `src/main/resources/application.yaml`.
All 44 workshop endpoints pass with Ollama.

## Why Qwen3 over Mistral?

The workshop uses **Qwen3 (8B)** as the default Ollama chat model because model choice matters — not every model can handle all AI capabilities equally:

- **Tool calling**: Qwen3 reliably executes function calls when the model receives tool definitions. Mistral (7B) often *describes* what it would do instead of actually invoking the tool, causing `chat_05` demos to fail silently.
- **Structured output**: Both models handle JSON schema conformance, but Qwen3 produces more consistent results for complex POJO mappings (`chat_04/object`).
- **Reasoning**: Qwen3 supports a built-in thinking mode that improves multi-step tasks like chain-of-thought (`cot/bio/flow`) and self-reflection agents.
- **Same weight class**: At 8B parameters (~8 GB RAM), Qwen3 runs on the same hardware as Mistral 7B with no additional resource requirements.

This is a practical example of why **model selection is an architectural decision** in AI applications — the same Spring AI code behaves differently depending on the model's capabilities.
