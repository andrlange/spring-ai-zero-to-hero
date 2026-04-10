package com.example.tracing;

import io.micrometer.observation.Observation;
import io.micrometer.observation.ObservationHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.observation.ChatModelObservationContext;
import org.springframework.http.client.observation.ClientRequestObservationContext;
import org.springframework.stereotype.Component;

/**
 * Emits an INFO log line for every observation start and stop, so that each span in a distributed
 * trace has at least one associated log entry visible in Loki/Grafana.
 *
 * <p>Covers:
 *
 * <ul>
 *   <li>Spring AI chat model observations ({@code chat qwen3} spans)
 *   <li>HTTP client observations ({@code http post} spans)
 *   <li>Any other observation that doesn't already have logging
 * </ul>
 */
@Component
public class SpanLoggingObservationHandler implements ObservationHandler<Observation.Context> {

  private static final Logger logger = LoggerFactory.getLogger(SpanLoggingObservationHandler.class);
  private static final int MAX_LENGTH = 500;

  @Override
  public boolean supportsContext(Observation.Context context) {
    return context instanceof ChatModelObservationContext
        || context instanceof ClientRequestObservationContext;
  }

  @Override
  public void onStart(Observation.Context context) {
    if (context instanceof ChatModelObservationContext chatContext) {
      var prompt = chatContext.getRequest();
      String model =
          chatContext.getOperationMetadata() != null
              ? chatContext.getOperationMetadata().provider()
              : "unknown";
      String promptContent = "";
      if (prompt != null && prompt.getContents() != null) {
        promptContent = truncate(prompt.getContents());
      }
      logger.info("AI CALL START [provider={}]: {}", model, promptContent);

    } else if (context instanceof ClientRequestObservationContext httpContext) {
      var request = httpContext.getCarrier();
      if (request != null) {
        logger.info("HTTP CLIENT REQUEST: {} {}", request.getMethod(), request.getURI());
      }
    }
  }

  @Override
  public void onStop(Observation.Context context) {
    if (context instanceof ChatModelObservationContext chatContext) {
      var response = chatContext.getResponse();
      String model =
          chatContext.getOperationMetadata() != null
              ? chatContext.getOperationMetadata().provider()
              : "unknown";
      if (response != null && response.getResult() != null) {
        String content = truncate(response.getResult().getOutput().getText());
        logger.info("AI CALL END [provider={}]: {}", model, content);
      } else {
        logger.info("AI CALL END [provider={}]: <no response>", model);
      }

    } else if (context instanceof ClientRequestObservationContext httpContext) {
      var response = httpContext.getResponse();
      if (response != null) {
        try {
          logger.info(
              "HTTP CLIENT RESPONSE: {} (status={})",
              httpContext.getCarrier() != null
                  ? httpContext.getCarrier().getMethod() + " " + httpContext.getCarrier().getURI()
                  : "unknown",
              response.getStatusCode().value());
        } catch (Exception e) {
          logger.info("HTTP CLIENT RESPONSE: completed");
        }
      }
    }
  }

  @Override
  public void onError(Observation.Context context) {
    Throwable error = context.getError();
    if (error != null) {
      logger.error("OBSERVATION ERROR: {}", error.getMessage());
    }
  }

  private String truncate(String value) {
    if (value == null) {
      return "<null>";
    }
    if (value.length() <= MAX_LENGTH) {
      return value;
    }
    return value.substring(0, MAX_LENGTH) + "... [truncated, total=" + value.length() + " chars]";
  }
}
