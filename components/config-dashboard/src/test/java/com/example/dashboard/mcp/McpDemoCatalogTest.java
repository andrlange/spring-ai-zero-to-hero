package com.example.dashboard.mcp;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class McpDemoCatalogTest {

  private final McpDemoCatalog catalog = new McpDemoCatalog();

  @Test
  void allReturnsFiveDemos() {
    assertThat(catalog.all()).extracting(McpDemo::id).containsExactly("01", "02", "03", "04", "05");
  }

  @Test
  void getHttpDemoReturnsPort() {
    assertThat(catalog.get("02").port()).isEqualTo(8081);
    assertThat(catalog.get("04").port()).isEqualTo(8082);
    assertThat(catalog.get("05").port()).isEqualTo(8083);
  }

  @Test
  void get01IsStdio() {
    McpDemo demo = catalog.get("01");
    assertThat(demo.transport()).isEqualTo(McpDemo.Transport.STDIO);
    assertThat(demo.port()).isNull();
  }

  @Test
  void get05HasAllThreeCapabilities() {
    assertThat(catalog.get("05").capabilities())
        .containsExactlyInAnyOrder(
            McpDemo.Capability.TOOLS, McpDemo.Capability.RESOURCES, McpDemo.Capability.PROMPTS);
  }

  @Test
  void getUnknownIdThrows() {
    assertThatThrownBy(() -> catalog.get("99")).isInstanceOf(IllegalArgumentException.class);
  }
}
