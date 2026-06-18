package com.example.vector_01;

import com.example.data.DataFiles;
import com.example.tracing.TracedEndpoint;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.io.File;
import java.io.IOException;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.ai.document.DocumentReader;
import org.springframework.ai.reader.JsonReader;
import org.springframework.ai.transformer.splitter.TokenTextSplitter;
import org.springframework.ai.vectorstore.SimpleVectorStore;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Stage 3: Vector Stores")
@TracedEndpoint
@RestController
@RequestMapping("/vector/01")
public class VectorStoreController {
  private final Logger logger = LoggerFactory.getLogger(VectorStoreController.class);

  private final DataFiles dataFiles;
  private final VectorStore vectorStore;

  public VectorStoreController(VectorStore vectorStore, DataFiles dataFiles) {
    this.dataFiles = dataFiles;
    this.vectorStore = vectorStore;
  }

  @Operation(
      summary = "Load documents into vector store",
      description = "Reads bike JSON, chunks, embeds, stores. Call before /query.")
  @ApiResponse(
      responseCode = "200",
      description = "Confirmation message with document count",
      content =
          @Content(examples = @ExampleObject(value = "vector store loaded with 10 documents")))
  @GetMapping("/load")
  public String load() throws IOException {
    // turn the json specs file into a document per bike
    DocumentReader reader =
        new JsonReader(
            this.dataFiles.getBikesResource(), "name", "price", "shortDescription", "description");
    List<Document> documents = reader.get();

    // chunk documents to fit embedding model context window (e.g., Ollama nomic-embed-text)
    TokenTextSplitter splitter = TokenTextSplitter.builder().build();
    List<Document> chunks = splitter.apply(documents);
    logger.info("Split {} documents into {} chunks", documents.size(), chunks.size());

    // add the chunked documents to the vector store
    this.vectorStore.add(chunks);

    var fileLocationMessage = "";
    if (vectorStore instanceof SimpleVectorStore) {
      var file = File.createTempFile("bike_vector_store", ".json");
      ((SimpleVectorStore) this.vectorStore).save(file);
      fileLocationMessage = "vector store file written to %s".formatted(file.getAbsolutePath());
      ;
      logger.info("vector store contents written to {}", file.getAbsolutePath());
    }

    return "vector store loaded with %s documents".formatted(documents.size());
  }

  @Operation(
      summary = "Semantic similarity search",
      description = "Searches vector store for semantically similar documents")
  @ApiResponse(
      responseCode = "200",
      description = "List of matching document texts",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value = "[\"Bike name: TrailBlazer X...\", \"Bike name: MountainKing...\"]")))
  @GetMapping("query")
  public List<String> query(
      @Parameter(
              description = "Semantic search query",
              example = "Which bikes have extra long range")
          @RequestParam(value = "topic", defaultValue = "Which bikes have extra long range")
          String topic) {

    // search the vector store for the top 4 bikes that match the query
    List<Document> topMatches = this.vectorStore.similaritySearch(topic);

    return topMatches.stream().map(Document::getText).toList();
  }
}
