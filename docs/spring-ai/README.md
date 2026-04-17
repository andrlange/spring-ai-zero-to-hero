# Spring AI Deep Dive Documentation

This folder contains in-depth technical documentation covering the Spring AI framework, AI model fundamentals, and detailed analysis of every demo in this workshop. Each document includes Spring AI component descriptions, Mermaid flow diagrams, and code examples — designed for instructors and developers who want to understand the full picture.

## Documents

| Document | Topic | What You'll Learn |
|----------|-------|-------------------|
| [SPRING_AI_INTRODUCTION.md](SPRING_AI_INTRODUCTION.md) | **Spring AI Fundamentals** | What Spring AI is, architecture overview, ChatModel vs ChatClient, provider portability, AI model capabilities (tool calling, multimodal vision/audio, structured output), provider compatibility matrix |
| [SPRING_AI_STAGE_1.md](SPRING_AI_STAGE_1.md) | **Chat Fundamentals** | 14 demos: ChatModel, ChatClient fluent API, prompt templates, structured output (List/Map/records), tool calling (@Tool, FunctionToolCallback, returnDirect), system roles, multimodal input, streaming with Flux |
| [SPRING_AI_STAGE_2.md](SPRING_AI_STAGE_2.md) | **Embeddings** | 10 demos: EmbeddingModel, vector dimensions, cosine similarity, context window limits, TokenTextSplitter chunking, document readers (JsonReader, TextReader, PagePdfDocumentReader, ParagraphPdfDocumentReader) |
| [SPRING_AI_STAGE_3.md](SPRING_AI_STAGE_3.md) | **Vector Stores** | 2 demos: VectorStore.add(), similaritySearch(), SimpleVectorStore vs PgVectorStore, profile-based backend switching, the complete ETL pipeline (Read → Split → Embed → Store → Search) |
| [SPRING_AI_STAGE_4.md](SPRING_AI_STAGE_4.md) | **AI Patterns** | 7 demos: stuff-the-prompt, manual RAG (search → format → prompt), advisor-based RAG (QuestionAnswerAdvisor), stateless vs stateful chat, chat memory (PromptChatMemoryAdvisor, MessageWindowChatMemory), advisor architecture |
| [SPRING_AI_STAGE_5.md](SPRING_AI_STAGE_5.md) | **Advanced Agent Patterns** | 4 demos: chain-of-thought (6-step pipeline with role-switching), self-reflection (Writer/Critic iterative loop), TikaDocumentReader for PDFs, task decomposition and output chaining |
| [SPRING_AI_STAGE_6.md](SPRING_AI_STAGE_6.md) · [What's New](../../WHATS_NEW_STAGE_06_MCP.md) | **Model Context Protocol (MCP)** | 6 demos: MCP servers (STDIO, Streamable HTTP), MCP clients, dynamic tool registration (McpSyncServer.addTool), full MCP capabilities (@McpResource, @McpPrompt, @McpComplete) — runnable from the dashboard at `/dashboard/stage/6` |
| [SPRING_AI_STAGE_7.md](SPRING_AI_STAGE_7.md) | **Agentic Systems** | 2 demos: inner monologue (forced tool calling, private reasoning), model-directed loop (multi-step with requestReinvocation control), Spring Shell CLI clients, chat memory across agent steps |
| [SPRING_AI_STAGE_8.md](SPRING_AI_STAGE_8.md) | **Observability** | Custom tracing annotations (@TracedEndpoint/Service/Repository), AOP span hierarchy, OpenTelemetry + LGTM stack (Grafana, Tempo, Loki, Mimir), trace-log-metric correlation, pre-provisioned dashboards |

## How to Use

- **Start with the Introduction** — read [SPRING_AI_INTRODUCTION.md](SPRING_AI_INTRODUCTION.md) first for a solid understanding of Spring AI's architecture, how models and providers work, and what capabilities (tool calling, vision, audio) require model-level support
- **Follow the stages in order** — each stage builds on concepts from previous stages
- **Use alongside the code** — every document references source files and endpoints you can run and explore
