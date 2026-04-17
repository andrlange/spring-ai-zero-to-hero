package com.example.dashboard.mcp;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;

class McpDemoTest {

  @Test
  void httpDemoExposesPort() {
    McpDemo demo =
        new McpDemo(
            "02",
            "HTTP Server",
            "Weather tools over HTTP",
            McpDemo.Transport.HTTP,
            8081,
            "mcp/02-mcp-http-server",
            List.of(McpDemo.Capability.TOOLS));

    assertThat(demo.port()).isEqualTo(8081);
    assertThat(demo.transport()).isEqualTo(McpDemo.Transport.HTTP);
    assertThat(demo.capabilities()).containsExactly(McpDemo.Capability.TOOLS);
  }

  @Test
  void stdioDemoHasNullPort() {
    McpDemo demo =
        new McpDemo(
            "01",
            "STDIO Server",
            "Weather tools over stdin/stdout",
            McpDemo.Transport.STDIO,
            null,
            "mcp/01-mcp-stdio-server",
            List.of(McpDemo.Capability.TOOLS));

    assertThat(demo.port()).isNull();
    assertThat(demo.transport()).isEqualTo(McpDemo.Transport.STDIO);
  }
}
