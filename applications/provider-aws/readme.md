# AWS Bedrock

**Spring Boot 4.0.6 | Spring AI 2.0.0-M7 | spring-ai-starter-model-bedrock-converse**

To run the sample application you will need AWS credentials configured.
AWS Bedrock uses your AWS IAM credentials, not a separate API key.

## Setup

Configure AWS CLI credentials:

```bash
aws configure
# Or set environment variables:
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1
```

Copy `src/main/resources/creds-template.yaml` to `src/main/resources/creds.yaml`
and configure the region and any model overrides.

## Run

```bash
./mvnw spring-boot:run -pl applications/provider-aws
```

Or run from the IDE for breakpoints.

## Models

- **Chat:** Claude (via Bedrock) or Amazon Titan
- **Embeddings:** Amazon Titan Embeddings
- **Note:** Not all Spring AI demos may be available (no image/audio generation)
