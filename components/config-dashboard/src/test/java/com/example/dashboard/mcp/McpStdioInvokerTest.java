package com.example.dashboard.mcp;

import static org.assertj.core.api.Assertions.assertThat;

import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class McpStdioInvokerTest {

  @Test
  void jarPresentReturnsTrueWhenFileExists(@TempDir Path tmp) throws Exception {
    Path jar = tmp.resolve("01.jar");
    Files.writeString(jar, "dummy");
    McpStdioInvoker invoker = new McpStdioInvoker(jar.toString());
    assertThat(invoker.jarPresent()).isTrue();
  }

  @Test
  void jarPresentReturnsFalseWhenMissing(@TempDir Path tmp) {
    Path jar = tmp.resolve("missing.jar");
    McpStdioInvoker invoker = new McpStdioInvoker(jar.toString());
    assertThat(invoker.jarPresent()).isFalse();
  }

  @Test
  void jarPathExposedForDashboardMessages() {
    McpStdioInvoker invoker = new McpStdioInvoker("/path/to/jar");
    assertThat(invoker.jarPath()).isEqualTo("/path/to/jar");
  }
}
