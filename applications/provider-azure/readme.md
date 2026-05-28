# Azure OpenAI

**Spring Boot 4.0.6 | Spring AI 2.0.0-M8 | spring-ai-starter-model-openai (Microsoft Foundry mode)**

All 8 chat endpoints pass with gpt-4.1-mini.

> **M5 migration note** — Spring AI 2.0.0-M6 removed `spring-ai-azure-openai`. Azure OpenAI is now served by the unified `spring-ai-openai` module under the **Microsoft Foundry** label. Foundry mode is auto-detected when `spring.ai.openai.base-url` ends with `openai.azure.com` (or `cognitiveservices.azure.com`), or when a `deployment-name` is set.

## Setup

1. Create an Azure OpenAI resource via Azure CLI or Portal:
   ```bash
   az cognitiveservices account create \
     --name your-resource-name \
     --resource-group your-resource-group \
     --location eastus \
     --kind OpenAI \
     --sku S0
   ```

2. Deploy a model:
   ```bash
   az cognitiveservices account deployment create \
     --name your-resource-name \
     --resource-group your-resource-group \
     --deployment-name gpt-41-mini \
     --model-name gpt-4.1-mini \
     --model-version "2025-04-14" \
     --model-format OpenAI \
     --sku-capacity 1 \
     --sku-name Standard
   ```

3. Copy `src/main/resources/creds-template.yaml` to `src/main/resources/creds.yaml`:

```yaml
spring:
  ai:
    openai:
      api-key: ...your-key...
      base-url: https://your-resource.openai.azure.com/
      chat:
        options:
          deployment-name: gpt-41-mini
          model: gpt-41-mini
```

Get your key: `az cognitiveservices account keys list --name your-resource-name --resource-group your-resource-group`

## Run

```bash
./mvnw spring-boot:run -pl applications/provider-azure
```

Or run from the IDE for breakpoints.

## Models

- **Chat:** gpt-4.1-mini (tested), gpt-4.1, gpt-4o, gpt-5 also available
- **Embeddings:** text-embedding-3-small/large (requires separate deployment)
- **Tool calling:** Yes
- **Image:** DALL-E 3 (if deployed)

## Notes

- Use **Standard** SKU (not GlobalStandard) for free tier deployments
- Older models like gpt-4o-mini v2024-07-18 are deprecated — use gpt-4.1-mini or newer
- Removed deprecated `spring.ai.azure.openai.chat.options.functions` config (Spring AI 2.0)
- Embedding module not tested (requires separate Azure OpenAI embedding deployment)
- Migrated from `spring-ai-starter-model-azure-openai` → `spring-ai-starter-model-openai` for Spring AI 2.0.0-M6
