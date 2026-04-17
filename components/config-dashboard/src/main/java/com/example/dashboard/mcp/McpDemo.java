package com.example.dashboard.mcp;

import java.util.List;

public record McpDemo(
    String id,
    String title,
    String oneLiner,
    Transport transport,
    Integer port,
    String modulePath,
    List<Capability> capabilities) {

  public enum Transport {
    STDIO,
    HTTP
  }

  public enum Capability {
    TOOLS,
    RESOURCES,
    PROMPTS
  }
}
