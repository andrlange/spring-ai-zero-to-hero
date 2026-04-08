# Stage 4: AI Patterns

**Modules:** `components/patterns/01-stuff-the-prompt/`, `02-retrieval-augmented-generation/`, `03-chat-memory/`
**Maven Artifacts:** `spring-ai-client-chat`, `spring-ai-vector-store`, `spring-ai-advisors-vector-store`
**Package Base:** `com.example.stuff_01`, `com.example.rag_01`, `com.example.rag_02`, `com.example.mem_01`, `com.example.mem_02`

---

## Overview

Stage 4 introduces three foundational AI application patterns that build on the chat, embedding, and vector store foundations from Stages 1–3:

1. **Stuff-the-Prompt** — Inject context data directly into the prompt
2. **Retrieval-Augmented Generation (RAG)** — Search a vector store for relevant context, then generate an answer
3. **Chat Memory** — Maintain conversation history across multiple requests

These patterns solve the core challenge of LLMs: **they only know what's in their training data**. By augmenting prompts with external data (stuff-the-prompt, RAG) or conversation history (chat memory), you ground the AI's responses in real, relevant information.

### Learning Objectives

After completing this stage, developers will be able to:

- Inject external context into prompts using the stuff-the-prompt pattern
- Build manual RAG pipelines: search → format → prompt → generate
- Use `QuestionAnswerAdvisor` for declarative, advisor-based RAG
- Understand Spring AI's advisor architecture for prompt augmentation
- Add conversation memory with `PromptChatMemoryAdvisor` and `MessageWindowChatMemory`
- Compare stateless vs. stateful chat interactions

### Prerequisites

> **Background reading:** See [SPRING_AI_INTRODUCTION.md](SPRING_AI_INTRODUCTION.md) for Spring AI fundamentals, [SPRING_AI_STAGE_2.md](SPRING_AI_STAGE_2.md) for embeddings, and [SPRING_AI_STAGE_3.md](SPRING_AI_STAGE_3.md) for vector stores.

- A running AI provider (Ollama with `qwen3` + `nomic-embed-text`)
- For RAG demos: vector store populated via `/load` endpoints

---

## Pattern Overview

```mermaid
graph TD
    A[User Question] --> B{Which Pattern?}

    B -->|Small, known context| C[Stuff-the-Prompt]
    B -->|Large corpus, dynamic| D[RAG]
    B -->|Multi-turn conversation| E[Chat Memory]

    C --> F[Load file → inject into prompt → LLM]
    D --> G[Search vector store → inject results → LLM]
    E --> H[Store history → inject prior messages → LLM]

    style A fill:#0277bd,color:#ffffff
    style B fill:#e65100,color:#ffffff
    style C fill:#1b5e20,color:#ffffff
    style D fill:#1b5e20,color:#ffffff
    style E fill:#1b5e20,color:#ffffff
    style F fill:#4a148c,color:#ffffff
    style G fill:#4a148c,color:#ffffff
    style H fill:#4a148c,color:#ffffff
```

---

## Spring AI Component Reference

| Component | FQN | Purpose |
|-----------|-----|---------|
| `ChatModel` | `o.s.ai.chat.model.ChatModel` | Low-level chat API (used in stuff-the-prompt) |
| `ChatClient` | `o.s.ai.chat.client.ChatClient` | Fluent chat API with advisor support |
| `Prompt` | `o.s.ai.chat.prompt.Prompt` | Request wrapper for messages |
| `PromptTemplate` | `o.s.ai.chat.prompt.PromptTemplate` | Template engine with `{variable}` substitution |
| `VectorStore` | `o.s.ai.vectorstore.VectorStore` | Similarity search for RAG context retrieval |
| `Document` | `o.s.ai.document.Document` | Text with metadata, used in vector search results |
| `TokenTextSplitter` | `o.s.ai.transformer.splitter.TokenTextSplitter` | Chunks documents for vector store ingestion |
| `QuestionAnswerAdvisor` | `o.s.ai.chat.client.advisor.vectorstore.QuestionAnswerAdvisor` | Advisor that automates RAG: search + prompt augmentation |
| `PromptChatMemoryAdvisor` | `o.s.ai.chat.client.advisor.PromptChatMemoryAdvisor` | Advisor that injects conversation history into prompts |
| `MessageWindowChatMemory` | `o.s.ai.chat.memory.MessageWindowChatMemory` | Sliding-window conversation memory |
| `InMemoryChatMemoryRepository` | `o.s.ai.chat.memory.InMemoryChatMemoryRepository` | In-memory storage for chat history |

> **Notation:** `o.s.ai` = `org.springframework.ai`

---

## Demo 01 — Stuff-the-Prompt

**Endpoint:** `GET /stuffit/01/query?message={question}`
**Source:** `stuff_01/StuffController.java`

### Description

The simplest context augmentation pattern. Loads an entire document (Wikipedia article on 2022 Olympics curling) from the classpath and injects it directly into the prompt alongside the user's question. The LLM answers based on the provided context rather than its training data. This works well for small, well-defined contexts but doesn't scale to large corpora.

### Spring AI Components

- `ChatModel` — low-level chat API
- `PromptTemplate` — loads template from classpath file (`prompts/qa-prompt.st`)
- `Prompt` — wraps the rendered template into a request

### Flow Diagram

```mermaid
sequenceDiagram
    participant Client as HTTP Client
    participant Controller as StuffController
    participant Template as PromptTemplate
    participant ChatModel as ChatModel
    participant LLM as AI Provider

    Client->>Controller: GET /stuffit/01/query?message=Who won gold?

    Controller->>Controller: Load context: classpath:/docs/wikipedia-curling.md
    Controller->>Controller: Load template: classpath:/prompts/qa-prompt.st

    Controller->>Template: new PromptTemplate(qaPromptResource)
    Controller->>Template: create({question: "Who won gold?", context: curlingArticle})
    Template-->>Controller: Prompt (context + question merged)

    Controller->>ChatModel: call(prompt)
    ChatModel->>LLM: Send prompt (full article + question)
    LLM-->>ChatModel: Answer based on provided context
    ChatModel-->>Controller: ChatResponse
    Controller->>Controller: response.getResult().getOutput().getText()
    Controller-->>Client: 200 OK — "Italy won the mixed doubles gold..."
```

### Key Code

```java
@Value("classpath:/docs/wikipedia-curling.md")
private Resource docsToStuffResource;

@Value("classpath:/prompts/qa-prompt.st")
private Resource qaPromptResource;

@GetMapping("/query")
public String query(@RequestParam(value = "message", defaultValue = "...") String message) {
    PromptTemplate promptTemplate = new PromptTemplate(qaPromptResource);
    Map<String, Object> map = new HashMap<>();
    map.put("question", message);
    map.put("context", docsToStuffResource);
    Prompt prompt = promptTemplate.create(map);
    return chatModel.call(prompt).getResult().getOutput().getText();
}
```

**Prompt template** (`prompts/qa-prompt.st`):
```
Use the following pieces of context to answer the question at the end.
If you don't know the answer, just say that you don't know, don't try to make up an answer.

{context}

Question: {question}
Helpful Answer:
```

> **Takeaway:** Stuff-the-prompt is the simplest RAG-like pattern — no embeddings or vector stores needed. Just load a document and inject it. The limitation: the entire document must fit in the LLM's context window. For larger corpora, use real RAG (Demo 02).

---

## Demo 02a — Manual RAG

**Endpoints:** `GET /rag/01/load` | `GET /rag/01/query?topic={topic}`
**Source:** `rag_01/RagController.java`

### Description

A full manual RAG implementation where you control every step: load documents into a vector store, search for relevant context, format it into the prompt, and generate an answer. This gives maximum visibility and control over the retrieval-generation pipeline.

### Spring AI Components

- `ChatClient` — fluent API with system prompt and template variables
- `VectorStore` — similarity search for retrieving relevant bike documents
- `JsonReader2` / `TokenTextSplitter` — document ingestion pipeline (same as Stage 3)
- `Document` — search results containing bike specifications

### Flow Diagram — Load

```mermaid
sequenceDiagram
    participant Client as HTTP Client
    participant Controller as RagController
    participant Reader as JsonReader2
    participant Splitter as TokenTextSplitter
    participant Store as VectorStore
    participant Model as EmbeddingModel
    participant Provider as AI Provider

    Client->>Controller: GET /rag/01/load

    Controller->>Reader: new JsonReader2(bikesResource, fields...)
    Controller->>Reader: get()
    Reader-->>Controller: List<Document>

    Controller->>Splitter: apply(documents)
    Splitter-->>Controller: List<Document> (chunks)

    Controller->>Store: add(chunks)
    loop For each chunk (internal)
        Store->>Model: embed(chunk)
        Model->>Provider: Generate embedding
        Provider-->>Model: float[]
        Model-->>Store: Store document + vector
    end

    Controller-->>Client: 200 OK — "loaded X chunks from Y documents"
```

### Flow Diagram — Query

```mermaid
sequenceDiagram
    participant Client as HTTP Client
    participant Controller as RagController
    participant Store as VectorStore
    participant ChatClient as ChatClient
    participant LLM as AI Provider

    Client->>Controller: GET /rag/01/query?topic=long range bikes

    Note over Controller: Step 1: Retrieve relevant context
    Controller->>Store: similaritySearch("long range bikes")
    Store-->>Controller: List<Document> (top 4 matches)

    Note over Controller: Step 2: Format context into prompt
    Controller->>Controller: Concatenate document texts into {context}

    Note over Controller: Step 3: Generate answer with context
    Controller->>ChatClient: .prompt().system("e-bike assistant").user({question} + {context})
    ChatClient->>LLM: System prompt + user question + bike specs
    LLM-->>ChatClient: Answer grounded in retrieved context
    ChatClient-->>Controller: .content()
    Controller-->>Client: 200 OK — "The TrailBlazer X offers the longest range..."
```

### Key Code

```java
@GetMapping("query")
public String query(@RequestParam(value = "topic", defaultValue = "Which bikes have extra long range") String topic) {
    // Step 1: Retrieve
    List<Document> topMatches = this.vectorStore.similaritySearch(topic);

    // Step 2: Format context
    String specs = topMatches.stream()
        .map(document -> "\n===\n" + document.getText() + "\n===\n")
        .collect(Collectors.joining());

    // Step 3: Generate
    return chatClient.prompt()
        .system("You are a helpful assistant at an e-bike store...")
        .user(u -> u.text("""
            Answer the question in <question></question> section based on the
            context in the <context></context> section
            <question>{question}</question>
            <context>{context}</context>
            """)
            .param("question", topic)
            .param("context", specs))
        .call().content();
}
```

> **Takeaway:** Manual RAG gives you full control: you choose how many documents to retrieve, how to format the context, and how to structure the prompt. The tradeoff is more code — the advisor-based approach (Demo 02b) automates this.

---

## Demo 02b — Advisor-Based RAG

**Endpoints:** `GET /rag/02/load` | `GET /rag/02/query?topic={topic}`
**Source:** `rag_02/AdvisorController.java`

### Description

The same RAG pipeline as Demo 02a, but automated using `QuestionAnswerAdvisor`. The advisor intercepts the ChatClient request, searches the vector store, injects the results into the prompt using a template, and passes everything to the LLM — all in a single declarative call.

### Spring AI Components

- `ChatClient` — fluent API with `.advisors()` for pluggable behavior
- `QuestionAnswerAdvisor` — automates vector search + prompt augmentation
- `VectorStore` — searched automatically by the advisor
- `PromptTemplate` — custom template for the advisor's context injection

### Flow Diagram — Query

```mermaid
sequenceDiagram
    participant Client as HTTP Client
    participant Controller as AdvisorController
    participant ChatClient as ChatClient
    participant Advisor as QuestionAnswerAdvisor
    participant Store as VectorStore
    participant Model as EmbeddingModel
    participant LLM as AI Provider

    Client->>Controller: GET /rag/02/query?topic=long range bikes

    Controller->>ChatClient: .prompt().advisors(QuestionAnswerAdvisor).user(topic)

    Note over ChatClient,Advisor: Advisor intercepts before LLM call
    ChatClient->>Advisor: Before call: user message = "long range bikes"

    Advisor->>Store: similaritySearch("long range bikes")
    Store->>Model: embed("long range bikes")
    Model-->>Store: float[] queryVector
    Store-->>Advisor: List<Document> (top matches)

    Advisor->>Advisor: Inject documents into prompt template<br/>{question_answer_context} → bike specs
    Advisor-->>ChatClient: Augmented prompt (user question + context)

    ChatClient->>LLM: System: "e-bike assistant" + User: question + context
    LLM-->>ChatClient: Answer grounded in retrieved documents
    ChatClient-->>Controller: .content()
    Controller-->>Client: 200 OK — "The TrailBlazer X offers the longest range..."
```

### Key Code

```java
// System prompt set at build time
public AdvisorController(VectorStore vectorStore, DataFiles dataFiles, ChatClient.Builder builder) {
    this.chatClient = builder
        .defaultSystem("You are a helpful assistant at an e-bike store...")
        .build();
}

// Custom advisor prompt template
private static final String USER_TEXT_ADVISE = """
    Given the context information below, surrounded ---------------------, and provided
    history information and not prior knowledge, reply to the user comment.
    If the answer is not in the context, inform the user that you can't answer the question.

    ---------------------
    {question_answer_context}
    ---------------------
    """;

@GetMapping("query")
public String query(@RequestParam(value = "topic", defaultValue = "Which bikes have extra long range") String topic) {
    return this.chatClient.prompt()
        .advisors(
            QuestionAnswerAdvisor.builder(vectorStore)
                .promptTemplate(new PromptTemplate(USER_TEXT_ADVISE))
                .build())
        .user(topic)
        .call().content();
}
```

> **Takeaway:** `QuestionAnswerAdvisor` reduces the RAG pipeline to a single line of advisor configuration. It handles search, context formatting, and prompt augmentation automatically. Use manual RAG when you need custom retrieval logic; use the advisor for standard RAG flows.

---

## Demo 03a — Stateless Chat (Baseline)

**Endpoints:** `GET /mem/01/hello?message={message}` | `GET /mem/01/name`
**Source:** `mem_01/StatelessController.java`

### Description

The baseline for understanding why chat memory matters. Two separate requests are made: first the user introduces themselves ("Hello my name is John"), then asks "What is my name?". Without memory, the second request has no context — the AI cannot recall the user's name.

### Spring AI Components

- `ChatClient` — fluent API (no advisors, no memory)

### Flow Diagram

```mermaid
sequenceDiagram
    participant Client as HTTP Client
    participant Controller as StatelessController
    participant ChatClient as ChatClient
    participant LLM as AI Provider

    Client->>Controller: GET /mem/01/hello?message=Hello my name is John
    Controller->>ChatClient: .prompt().user("Hello my name is John").call()
    ChatClient->>LLM: "Hello my name is John"
    LLM-->>ChatClient: "Hello John! How can I help you?"
    ChatClient-->>Controller: .content()
    Controller-->>Client: 200 OK — greeting response

    Note over Controller: No memory — previous message is lost

    Client->>Controller: GET /mem/01/name
    Controller->>ChatClient: .prompt().user("What is my name?").call()
    ChatClient->>LLM: "What is my name?"
    LLM-->>ChatClient: "I don't know your name, you haven't told me."
    ChatClient-->>Controller: .content()
    Controller-->>Client: 200 OK — AI cannot recall name
```

### Key Code

```java
@GetMapping("/hello")
public String query(@RequestParam(value = "message",
    defaultValue = "Hello my name is John, what is the capital of France?") String message) {
    return chatClient.prompt().user(message).call().content();
}

@GetMapping("/name")
public String name() {
    return chatClient.prompt().user("What is my name?").call().content();
}
```

> **Takeaway:** By default, each `ChatClient` call is independent — no conversation history is maintained. The LLM sees only the current message. This is the problem that chat memory solves.

---

## Demo 03b — Chat Memory with Advisor

**Endpoints:** `GET /mem/02/hello?message={message}` | `GET /mem/02/name`
**Source:** `mem_02/ChatHistoryController.java`

### Description

Adds conversation memory using `PromptChatMemoryAdvisor`. The advisor stores each message in a `MessageWindowChatMemory` backed by `InMemoryChatMemoryRepository`, and injects prior messages into subsequent prompts. Now when the user asks "What is my name?", the AI recalls the name from the stored conversation history.

### Spring AI Components

- `ChatClient` — fluent API with `.advisors()` for memory injection
- `PromptChatMemoryAdvisor` — advisor that injects conversation history into prompts
- `MessageWindowChatMemory` — sliding-window memory (keeps the last N messages)
- `InMemoryChatMemoryRepository` — in-memory storage backend for conversation history

### Flow Diagram

```mermaid
sequenceDiagram
    participant Client as HTTP Client
    participant Controller as ChatHistoryController
    participant ChatClient as ChatClient
    participant Advisor as PromptChatMemoryAdvisor
    participant Memory as MessageWindowChatMemory
    participant LLM as AI Provider

    Client->>Controller: GET /mem/02/hello?message=Hello my name is John

    Controller->>ChatClient: .prompt().advisors(memoryAdvisor).user("Hello my name is John")
    ChatClient->>Advisor: Before call
    Advisor->>Memory: Retrieve prior messages (empty on first call)
    Memory-->>Advisor: [] (no history)
    Advisor-->>ChatClient: Prompt with user message only

    ChatClient->>LLM: "Hello my name is John"
    LLM-->>ChatClient: "Hello John! How can I help you?"
    ChatClient->>Advisor: After call
    Advisor->>Memory: Store user message + assistant response
    ChatClient-->>Controller: .content()
    Controller-->>Client: 200 OK — "Hello John!"

    Note over Memory: History now contains:<br/>User: "Hello my name is John"<br/>Assistant: "Hello John!"

    Client->>Controller: GET /mem/02/name

    Controller->>ChatClient: .prompt().advisors(memoryAdvisor).user("What is my name?")
    ChatClient->>Advisor: Before call
    Advisor->>Memory: Retrieve prior messages
    Memory-->>Advisor: [User: "Hello my name is John", Assistant: "Hello John!"]
    Advisor-->>ChatClient: Prompt with history + current message

    ChatClient->>LLM: History + "What is my name?"
    LLM-->>ChatClient: "Your name is John, as you mentioned earlier."
    ChatClient->>Advisor: After call
    Advisor->>Memory: Store this exchange too
    ChatClient-->>Controller: .content()
    Controller-->>Client: 200 OK — "Your name is John"
```

### Key Code

```java
public ChatHistoryController(ChatClient.Builder builder) {
    this.chatClient = builder.build();

    // Build memory stack: repository → memory → advisor
    var memory = MessageWindowChatMemory.builder()
        .chatMemoryRepository(new InMemoryChatMemoryRepository())
        .build();
    this.promptChatMemoryAdvisor = PromptChatMemoryAdvisor.builder(memory).build();
}

@GetMapping("/hello")
public String query(@RequestParam(value = "message",
    defaultValue = "Hello my name is John, what is the capital of France?") String message) {
    return this.chatClient.prompt()
        .advisors(promptChatMemoryAdvisor)
        .user(message)
        .call().content();
}

@GetMapping("/name")
public String name() {
    return this.chatClient.prompt()
        .advisors(promptChatMemoryAdvisor)
        .user("What is my name?")
        .call().content();
}
```

> **Takeaway:** Chat memory is implemented as an advisor that intercepts the ChatClient call. The memory stack has three layers: `InMemoryChatMemoryRepository` (storage) → `MessageWindowChatMemory` (windowing strategy) → `PromptChatMemoryAdvisor` (prompt injection). Adding `.advisors(memoryAdvisor)` is the only code change from stateless to stateful.

---

## The Advisor Architecture

Spring AI advisors are interceptors that modify prompts before they reach the LLM and/or process responses after. They follow the same pattern as Spring MVC interceptors or servlet filters:

```mermaid
sequenceDiagram
    participant App as Your Code
    participant A1 as Advisor 1<br/>(e.g., Memory)
    participant A2 as Advisor 2<br/>(e.g., RAG)
    participant LLM as AI Provider

    App->>A1: ChatClient.prompt().advisors(a1, a2).call()
    A1->>A1: Inject conversation history
    A1->>A2: Pass augmented prompt
    A2->>A2: Search vector store, inject context
    A2->>LLM: Final augmented prompt
    LLM-->>A2: Response
    A2-->>A1: Pass response
    A1->>A1: Store messages in memory
    A1-->>App: Final response
```

### Advisors Used in This Stage

| Advisor | Purpose | Intercepts |
|---------|---------|------------|
| `QuestionAnswerAdvisor` | Searches vector store, injects results into prompt | Before call |
| `PromptChatMemoryAdvisor` | Injects conversation history, stores new messages | Before + after call |

Advisors are composable — you can chain memory + RAG in a single request:
```java
chatClient.prompt()
    .advisors(memoryAdvisor, ragAdvisor)
    .user("What bikes did we discuss?")
    .call().content();
```

---

## Stage 4 Progression

```mermaid
graph LR
    A[01: Stuff-the-Prompt] --> B[02a: Manual RAG]
    B --> C[02b: Advisor RAG]
    D[03a: Stateless Baseline] --> E[03b: Chat Memory]
    C --> F[Stage 5: Advanced Patterns]
    E --> F

    style A fill:#0277bd,color:#ffffff
    style B fill:#01579b,color:#ffffff
    style C fill:#4a148c,color:#ffffff
    style D fill:#e65100,color:#ffffff
    style E fill:#bf360c,color:#ffffff
    style F fill:#1b5e20,color:#ffffff
```

### Pattern Comparison

| Pattern | Context Source | Scalability | Complexity | Best For |
|---------|---------------|-------------|------------|----------|
| **Stuff-the-Prompt** | Static file on classpath | Limited by LLM context window | Low | Small, known documents |
| **Manual RAG** | Vector store search | Scales to millions of documents | Medium | Custom retrieval logic |
| **Advisor RAG** | Vector store (automatic) | Same as manual RAG | Low | Standard RAG with defaults |
| **Chat Memory** | Conversation history | Bounded by window size | Low | Multi-turn conversations |

### Memory Stack Architecture

```
┌────────────────────────────────┐
│    PromptChatMemoryAdvisor     │  ← Injects history into prompt
├────────────────────────────────┤
│    MessageWindowChatMemory     │  ← Sliding window (last N messages)
├────────────────────────────────┤
│  InMemoryChatMemoryRepository  │  ← Storage backend (in-memory)
└────────────────────────────────┘
         Could also be:
    JdbcChatMemoryRepository (persistent)
    RedisChatMemoryRepository (distributed)
```
