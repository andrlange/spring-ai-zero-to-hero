package com.example.dashboard;

import java.util.List;

public record StageDefinition(
    int number,
    String name,
    String shortName,
    String tagName,
    String description,
    String accentColor,
    List<EndpointInfo> endpoints) {

  public record EndpointInfo(
      String path,
      String method,
      String summary,
      String description,
      String group,
      List<ParamInfo> params,
      String responseViewType) {}

  public record ParamInfo(
      String name,
      String description,
      String example,
      boolean required,
      List<String> allowedValues) {}

  public static List<StageDefinition> defaults() {
    return List.of(
        new StageDefinition(
            1,
            "Chat Fundamentals",
            "1. Chat",
            "Stage 1: Chat",
            "Basic chat, ChatClient, prompts, structured output, tools, roles, multimodal,"
                + " streaming",
            "#6db33f",
            List.of()),
        new StageDefinition(
            2,
            "Embeddings",
            "2. Embed",
            "Stage 2: Embeddings",
            "Vectors, similarity, chunking, document readers (JSON, text, PDF)",
            "#6b9bd2",
            List.of()),
        new StageDefinition(
            3,
            "Vector Stores",
            "3. Vector",
            "Stage 3: Vector Stores",
            "Load documents, semantic similarity search (SimpleVectorStore / PgVector)",
            "#d4a84a",
            List.of()),
        new StageDefinition(
            4,
            "AI Patterns",
            "4. Pattern",
            "Stage 4: Patterns",
            "Stuff-the-prompt, RAG (manual + advisor), chat memory",
            "#c678dd",
            List.of()),
        new StageDefinition(
            5,
            "Advanced Agents",
            "5. Agent",
            "Stage 5: Agents",
            "Chain of thought, self-reflection (writer + critic loop)",
            "#e06c75",
            List.of()),
        mcpStage());
  }

  public static StageDefinition mcpStage() {
    return new StageDefinition(
        6,
        "Model Context Protocol",
        "6. MCP",
        "Stage 6: MCP",
        "MCP servers (STDIO, Streamable HTTP), clients, dynamic tools, resources, prompts",
        "#0277bd",
        List.of());
  }
}
