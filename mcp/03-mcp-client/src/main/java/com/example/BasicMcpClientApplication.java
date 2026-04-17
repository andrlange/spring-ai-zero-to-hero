package com.example;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class BasicMcpClientApplication {

  public static void main(String[] args) {
    SpringApplication.run(BasicMcpClientApplication.class, args).close();
  }

  @Bean
  public CommandLineRunner chatbot(McpClientDemoRunner runner) {
    return args -> {
      String mode = System.getenv("MCP_DEMO_MODE");
      if (mode == null || mode.isBlank()) mode = "local";
      runner.run(mode);
    };
  }
}
