package com.example.embed_03;

import com.example.data.DataFiles;
import com.example.tracing.TracedEndpoint;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.springframework.ai.document.Document;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.transformer.splitter.TokenTextSplitter;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Stage 2: Embeddings")
@TracedEndpoint
@RestController
@RequestMapping("/embed/03")
public class EmbeddingRequestController {

  private final EmbeddingModel embeddingModel;
  private final String shakespeareWorks;
  private final DataFiles dataFiles;

  public EmbeddingRequestController(EmbeddingModel embeddingModel, DataFiles dataFiles)
      throws IOException {
    this.embeddingModel = embeddingModel;
    this.dataFiles = dataFiles;
    this.shakespeareWorks =
        this.dataFiles.getShakespeareWorksResource().getContentAsString(StandardCharsets.UTF_8);
  }

  @Operation(
      summary = "Embed a large document",
      description = "Attempts to embed Shakespeare's complete works. Shows context length limits.")
  @ApiResponse(
      responseCode = "200",
      description = "Success or error message describing the embedding result",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "Error: document of length 5458199 could not be embedded\nException Message: ...")))
  @GetMapping("big")
  public String bigFile(
      @Parameter(
              description =
                  "Document size: 'small' (~300 chars, fits context) or 'large' (5.5MB Shakespeare, exceeds context)")
          @RequestParam(value = "size", defaultValue = "large")
          @io.swagger.v3.oas.annotations.media.Schema(allowableValues = {"small", "large"})
          String size) {
    String text;
    if ("small".equalsIgnoreCase(size)) {
      text =
          "Spring AI provides a unified API for integrating AI models into Spring applications. "
              + "It supports multiple providers including OpenAI, Anthropic, Google, Azure, AWS Bedrock, "
              + "and Ollama. Key features include chat completion, embedding generation, vector stores, "
              + "and tool calling. The framework follows Spring conventions for configuration and "
              + "dependency injection.";
    } else {
      text = shakespeareWorks;
    }
    try {
      float[] embedding = embeddingModel.embed(text);
      return """
           Success: document of length %s characters was embedded into \
           1 vector with dimension %s"""
          .formatted(text.length(), embedding.length);
    } catch (Exception e) {
      return """
          Error: document of length %s could not be embedded
          Exception: %s"""
          .formatted(text.length(), e.getMessage());
    }
  }

  @Operation(
      summary = "Chunk and embed a large document",
      description = "Uses TokenTextSplitter to chunk before embedding")
  @ApiResponse(
      responseCode = "200",
      description = "Summary of chunk count and embeddings created",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "file split into 1245 chunks 3 embeddings created\nbecause we don't want to waste money by embedding every chunk")))
  @GetMapping("chunk")
  public String chunkFile() {
    TokenTextSplitter tokenTextSplitter = TokenTextSplitter.builder().build();
    List<String> chunks =
        tokenTextSplitter.split(new Document(shakespeareWorks)).stream()
            .map(d -> d.getText())
            .toList();
    // for demo purposes we will only compute the
    // embeddings of the first 3 chunks, since we have to pay
    // per token when we call the LLM
    List<float[]> embeddings = this.embeddingModel.embed(chunks.subList(0, 3));

    return """
           file split into %s chunks %s embeddings created
           because we don't want to waste money by embedding every chunk
        """
        .formatted(chunks.size(), embeddings.size());
  }
}
