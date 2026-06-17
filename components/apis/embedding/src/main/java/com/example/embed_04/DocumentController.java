package com.example.embed_04;

import com.example.data.DataFiles;
import com.example.tracing.TracedEndpoint;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.io.IOException;
import java.util.List;
import org.springframework.ai.document.Document;
import org.springframework.ai.document.DocumentReader;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.reader.ExtractedTextFormatter;
import org.springframework.ai.reader.JsonReader;
import org.springframework.ai.reader.TextReader;
import org.springframework.ai.reader.pdf.PagePdfDocumentReader;
import org.springframework.ai.reader.pdf.ParagraphPdfDocumentReader;
import org.springframework.ai.reader.pdf.config.PdfDocumentReaderConfig;
import org.springframework.ai.transformer.splitter.TokenTextSplitter;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Stage 2: Embeddings")
@TracedEndpoint
@RestController
@RequestMapping("/embed/04")
public class DocumentController {

  private final EmbeddingModel embeddingModel;
  private final DataFiles dataFiles;

  public DocumentController(EmbeddingModel embeddingModel, DataFiles dataFiles) throws IOException {
    this.embeddingModel = embeddingModel;
    this.dataFiles = dataFiles;
  }

  @Operation(
      summary = "Read and embed JSON documents",
      description = "JsonReader: loads bike data from JSON")
  @ApiResponse(
      responseCode = "200",
      description = "Summary of parsed documents and embedding details",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "Input file was parsed into 10 documents\nEmbedding for example document computed has 1536 dimensions\n...")))
  @GetMapping("json/bikes")
  public String bikeJsonToDocs() {
    DocumentReader reader =
        new JsonReader(
            this.dataFiles.getBikesResource(), "name", "price", "shortDescription", "description");
    List<Document> documents = reader.get();
    Document document = documents.get(0);
    float[] embedding = this.embeddingModel.embed(document);

    return """
                Input file was parsed into %s documents
                Embedding for example document computed has %s dimensions
                document id is %s
                document metadata is %s
                document embedding is %s
                Example contents after the dashed line below
                ---
                %s
                """
        .formatted(
            documents.size(),
            Integer.valueOf(embedding.length),
            document.getId(),
            document.getMetadata(),
            embedding,
            document.getText());
  }

  @Operation(
      summary = "Read and embed text documents",
      description = "TextReader: loads plain text, chunks, creates Documents")
  @ApiResponse(
      responseCode = "200",
      description = "Summary of parsed documents, chunk count, and embedding details",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "Input file was parsed into 1 documents\nThe document was too big and it was split into 1245 chunks\n...")))
  @GetMapping("text/works")
  public String getShakespeareWorks() {
    DocumentReader reader = new TextReader(this.dataFiles.getShakespeareWorksResource());
    List<Document> documents = reader.get();
    TokenTextSplitter tokenTextSplitter = TokenTextSplitter.builder().build();
    List<Document> chunks = tokenTextSplitter.apply(documents);
    Document document = chunks.get(0);
    float[] embedding = this.embeddingModel.embed(document);

    return """
                Input file was parsed into %s documents
                The document was too big and it was split into %s chunks
                Embedding for example document computed has %s dimensions
                document id is %s
                document metadata is %s
                document embedding is %s
                Example contents after the dashed line below
                ---
                %s
                """
        .formatted(
            documents.size(),
            chunks.size(),
            Integer.valueOf(embedding.length),
            document.getId(),
            document.getMetadata(),
            embedding,
            document.getText());
  }

  @Operation(
      summary = "Read PDF by page",
      description = "PagePdfDocumentReader: one Document per page")
  @ApiResponse(
      responseCode = "200",
      description = "Summary of pages read and embedding details",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "Input pdf read from bylaw.pdf\nEach page of the pdf was turned into a Document object\n42 total Document objects were created\n...")))
  @GetMapping("pdf/pages")
  public String getBylaw() {
    PagePdfDocumentReader pdfReader =
        new PagePdfDocumentReader(
            this.dataFiles.getBylawResource(),
            PdfDocumentReaderConfig.builder()
                .withPageExtractedTextFormatter(
                    ExtractedTextFormatter.builder()
                        .withNumberOfBottomTextLinesToDelete(3)
                        .withNumberOfTopPagesToSkipBeforeDelete(1)
                        .build())
                .withPagesPerDocument(1)
                .build());
    List<Document> documents = pdfReader.get();

    var pdfToDocsSummary =
        """
            Input pdf read from %s
            Each page of the pdf was turned into a Document object
            %s total Document objects were created
            document id is %s
            document metadata is %s
            first document contents between the two dashed lines below
            ---
            %s
            ---
            """
            .formatted(
                dataFiles.getBylawResource().getFilename(),
                documents.size(),
                documents.get(0).getId(),
                documents.get(0).getMetadata(),
                documents.get(0).getText());

    TokenTextSplitter tokenTextSplitter = TokenTextSplitter.builder().build();
    List<Document> chunks = tokenTextSplitter.apply(documents);
    Document document = documents.get(0);
    float[] embedding = this.embeddingModel.embed(document);

    var chuckSummary =
        """
                \nPDF page per doc might be too big we split each doc into chunks
                %s chunk documents were created
                Embedding for example first chunk computed has %s dimensions
                document id is %s
                document metadata is %s
                document embedding is %s
                Example contents after the dashed line below
                ---
                %s
                """
            .formatted(
                chunks.size(),
                Integer.valueOf(embedding.length),
                document.getId(),
                document.getMetadata(),
                embedding,
                document.getText());

    return pdfToDocsSummary + chuckSummary;
  }

  @Operation(
      summary = "Read PDF by paragraph",
      description = "ParagraphPdfDocumentReader: one Document per paragraph")
  @ApiResponse(
      responseCode = "200",
      description = "Summary of paragraphs read as Document objects",
      content =
          @Content(
              examples =
                  @ExampleObject(
                      value =
                          "Input pdf read from bylaw.pdf\nEach paragraph of the pdf was turned into a Document object\n...")))
  @GetMapping("/pdf/para")
  public String paragraphs() {
    ParagraphPdfDocumentReader pdfReader =
        new ParagraphPdfDocumentReader(
            this.dataFiles.getBylawResource(), PdfDocumentReaderConfig.builder().build());

    List<Document> documents = pdfReader.get();

    this.embeddingModel.embed(documents.get(0));
    var pdfToDocsSummary =
        """
            Input pdf read from %s
            Each paragraph of the pdf was turned into a Document object
            %s total Document objects were created
            document id is %s
            document metadata is %s
            first document contents between the two dashed lines below
            ---
            %s
            ---
            """
            .formatted(
                this.dataFiles.getBylawResource().getFilename(),
                documents.size(),
                documents.get(0).getId(),
                documents.get(0).getMetadata(),
                documents.get(0).getText());

    return pdfToDocsSummary;
  }
}
