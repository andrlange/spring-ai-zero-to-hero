package com.example.log;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class OpenAiAuditor implements Auditor {

  private static final Logger logger = LoggerFactory.getLogger(OpenAiAuditor.class);
  private static final int MAX_BODY_LENGTH = 1000;

  @Override
  public void log(AuditLogEntry auditEntry) {
    var request = auditEntry.getRequest();
    var response = auditEntry.getResponse();
    String id = auditEntry.getId().toString().substring(0, 8);

    // Log request
    logger.info(
        "GATEWAY REQUEST [id={}]: {} {} [body={}]",
        id,
        request.getMethod(),
        request.getDestinationUri(),
        truncate(request.getBody()));

    // Log response
    logger.info("GATEWAY RESPONSE [id={}]: [body={}]", id, truncate(response.getBody()));
  }

  private String truncate(String value) {
    if (value == null || value.isEmpty()) {
      return "<empty>";
    }
    if (value.length() <= MAX_BODY_LENGTH) {
      return value;
    }
    return value.substring(0, MAX_BODY_LENGTH)
        + "... [truncated, total="
        + value.length()
        + " chars]";
  }
}
