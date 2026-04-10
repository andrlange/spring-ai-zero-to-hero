package com.example;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.stereotype.Component;

/**
 * Installs the OpenTelemetry Logback Appender after the Spring Context is initialized. Required
 * because the OpenTelemetry SDK must be fully configured before the Logback Appender can export
 * logs to the OTLP endpoint (Loki via LGTM stack).
 */
@Component
public class OpenTelemetryLogbackInstaller implements InitializingBean {

  private static final Logger logger = LoggerFactory.getLogger(OpenTelemetryLogbackInstaller.class);

  private final OpenTelemetry openTelemetry;

  OpenTelemetryLogbackInstaller(OpenTelemetry openTelemetry) {
    this.openTelemetry = openTelemetry;
  }

  @Override
  public void afterPropertiesSet() {
    OpenTelemetryAppender.install(openTelemetry);
    logger.info("OpenTelemetry Logback Appender installed for gateway");
  }
}
