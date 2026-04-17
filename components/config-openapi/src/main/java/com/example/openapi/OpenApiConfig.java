package com.example.openapi;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.models.Paths;
import java.util.TreeMap;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@OpenAPIDefinition(
    info =
        @Info(
            title = "Spring AI Zero-to-Hero Workshop",
            version = "2.0.0-M4",
            description =
                """
                Interactive workshop demonstrating Spring AI capabilities across 5 stages.

                **Tech Stack:** Spring Boot 4.0.5 | Spring AI 2.0.0-M4 | Java 25

                **Endpoints are provider-independent** — the same API works with Ollama, OpenAI, \
                Anthropic, Azure, Google, and AWS Bedrock. The active provider depends on which \
                application module is running.
                """),
    tags = {
      @Tag(
          name = "Stage 1: Chat",
          description =
              "Chat fundamentals — basic calls, ChatClient, prompts, structured output, tool calling, system roles, multimodal, streaming"),
      @Tag(
          name = "Stage 2: Embeddings",
          description =
              "Embedding vectors, cosine similarity, chunking, document readers (JSON, text, PDF)"),
      @Tag(
          name = "Stage 3: Vector Stores",
          description =
              "Document loading into vector store, semantic similarity search (SimpleVectorStore or PgVector)"),
      @Tag(
          name = "Stage 4: Patterns",
          description =
              "AI patterns — stuff-the-prompt, RAG (manual and advisor-based), chat memory"),
      @Tag(
          name = "Stage 5: Agents",
          description =
              "Advanced agent patterns — chain of thought (single vs multi-step), self-reflection (writer + critic loop)"),
      @Tag(
          name = "Stage 6: MCP",
          description =
              "Model Context Protocol — MCP servers (STDIO, Streamable HTTP), clients, dynamic tools, resources, prompts. Runnable from the /dashboard/stage/6 page.")
    })
public class OpenApiConfig {

  @Bean
  public OpenApiCustomizer sortPathsAlphabetically() {
    return openApi -> {
      Paths original = openApi.getPaths();
      if (original == null) return;
      Paths sorted = new Paths();
      new TreeMap<>(original).forEach(sorted::addPathItem);
      openApi.setPaths(sorted);
    };
  }
}
