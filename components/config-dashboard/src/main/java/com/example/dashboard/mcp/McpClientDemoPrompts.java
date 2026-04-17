package com.example.dashboard.mcp;

public final class McpClientDemoPrompts {

  private McpClientDemoPrompts() {}

  public static final String SYSTEM =
      "You are a useful assistant that can call MCP tools to answer user questions.";

  public static final String DEFAULT_QUESTION =
      "What tools are available? Please give each tool's name and a one-sentence description.";

  public static final String LOCAL_DEMO_QUESTION =
      "Call the weather tool for Berlin (latitude 52.52, longitude 13.41) and summarize the result.";

  public static final String EXTERNAL_DEMO_QUESTION =
      "Does the Spring IO 2025 conference have sessions about Spring AI and the Model Context"
          + " Protocol? Please cite sources.";
}
