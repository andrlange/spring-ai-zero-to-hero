# Spring AI Zero-to-Hero Workshop

**Spring Boot 4.0.5 | Spring AI 2.0.0-M4 | Java 25**

A hands-on workshop for building AI-powered applications with Spring AI. Covers chat, embeddings, vector stores, RAG, tool calling, MCP, agentic patterns, and observability — across 6 AI providers.

## Getting Started

| Audience | Guide |
|----------|-------|
| **Workshop attendee** (live session) | [Quickstart](quickstart.md) — 5 minutes to your first AI call |
| **Self-paced learner** | [Full Guide](guide.md) — complete walkthrough of all 8 stages |

## Spring AI Deep Dive Documentation

In-depth technical documentation covering Spring AI internals, AI model fundamentals (LLMs, tool calling, multimodal architecture), and detailed analysis of every demo across all 8 stages — with Mermaid flow diagrams and annotated code examples.

| Document | Topic |
|----------|-------|
| [Introduction](spring-ai/SPRING_AI_INTRODUCTION.md) | Spring AI architecture, ChatModel vs ChatClient, provider portability, AI model capabilities (tool calling, vision, audio, structured output), provider compatibility matrix |
| [Stage 1: Chat](spring-ai/SPRING_AI_STAGE_1.md) | ChatModel, ChatClient, prompt templates, structured output, tool calling, system roles, multimodal, streaming |
| [Stage 2: Embeddings](spring-ai/SPRING_AI_STAGE_2.md) | EmbeddingModel, cosine similarity, TokenTextSplitter, document readers (JSON, Text, PDF) |
| [Stage 3: Vector Stores](spring-ai/SPRING_AI_STAGE_3.md) | VectorStore abstraction, SimpleVectorStore vs PgVectorStore, ETL pipeline |
| [Stage 4: AI Patterns](spring-ai/SPRING_AI_STAGE_4.md) | Stuff-the-prompt, manual and advisor-based RAG, chat memory, advisor architecture |
| [Stage 5: Advanced Agents](spring-ai/SPRING_AI_STAGE_5.md) | Chain-of-thought pipeline, self-reflection Writer/Critic loop, TikaDocumentReader |
| [Stage 6: MCP](spring-ai/SPRING_AI_STAGE_6.md) · [What's New](../WHATS_NEW_STAGE_06_MCP.md) | MCP servers (STDIO, HTTP), clients, dynamic tools, resources, prompts, completions — runnable from `/dashboard/stage/6` |
| [Stage 7: Agentic Systems](spring-ai/SPRING_AI_STAGE_7.md) | Inner monologue, model-directed loop, forced tool calling, Spring Shell CLIs |
| [Stage 8: Observability](spring-ai/SPRING_AI_STAGE_8.md) | Custom tracing annotations, OpenTelemetry, LGTM stack, trace-log-metric correlation |

## Resources

- [Provider Setup](providers.md) — comparison matrix, API keys, model requirements
- [Troubleshooting](troubleshooting.md) — common issues and solutions
- **Swagger UI** — http://localhost:8080/swagger-ui.html (when running)
- **Workshop Dashboard** — http://localhost:8080/dashboard (when running with `ui` profile)
- **Grafana** — http://localhost:3000 (when running with `observation` profile)
