package com.example.dashboard.mcp;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.ServerSocket;
import org.junit.jupiter.api.Test;

class McpClientRegistryTest {

  @Test
  void isUpReturnsFalseForClosedPort() {
    McpDemoCatalog catalog = new McpDemoCatalog();
    McpClientRegistry registry = new McpClientRegistry(catalog);

    assertThat(registry.isUp("02")).isFalse();
  }

  @Test
  void isUpReturnsFalseForStdioDemoWithoutJar() {
    McpDemoCatalog catalog = new McpDemoCatalog();
    McpClientRegistry registry = new McpClientRegistry(catalog);

    assertThat(registry.isUp("01")).isFalse();
  }

  @Test
  void probePortDetectsBoundSocket() throws Exception {
    McpDemoCatalog catalog = new McpDemoCatalog();
    McpClientRegistry registry = new McpClientRegistry(catalog);

    try (ServerSocket socket = new ServerSocket(0)) {
      int boundPort = socket.getLocalPort();
      assertThat(registry.probePort(boundPort)).isTrue();
    }

    int closedPort;
    try (ServerSocket socket = new ServerSocket(0)) {
      closedPort = socket.getLocalPort();
    }
    assertThat(registry.probePort(closedPort)).isFalse();
  }
}
