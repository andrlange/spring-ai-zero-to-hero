package com.example.tracing;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Scope;
import jakarta.servlet.http.HttpServletRequest;
import java.lang.annotation.Annotation;
import java.lang.reflect.Method;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;
import tools.jackson.databind.ObjectMapper;

/**
 * AOP Aspect for controller tracing. Creates root spans with SpanKind.SERVER for HTTP requests.
 * Order(1) ensures this aspect executes first in the chain.
 *
 * <p>Trace hierarchy:
 *
 * <pre>
 * HTTP Request
 *   -> @TracedEndpoint: "GET /rag/01/query" (SERVER)       <- this aspect
 *       -> @TracedService: "RagService.query" (INTERNAL)
 *           -> @TracedRepository: "VectorStore.search" (CLIENT)
 * </pre>
 */
@Aspect
@Component
@Order(1)
public class ControllerTracingAspect {

  private static final Logger logger = LoggerFactory.getLogger(ControllerTracingAspect.class);
  private static final int MAX_RESPONSE_LENGTH = 1000;

  private final Tracer tracer;
  private final ObjectMapper objectMapper = new ObjectMapper();

  public ControllerTracingAspect(Tracer tracer) {
    this.tracer = tracer;
  }

  private String truncate(String value) {
    if (value == null) {
      return "<null>";
    }
    if (value.length() <= MAX_RESPONSE_LENGTH) {
      return value;
    }
    return value.substring(0, MAX_RESPONSE_LENGTH)
        + "... [truncated, total="
        + value.length()
        + " chars]";
  }

  @Around(
      "@within(com.example.tracing.TracedEndpoint) || "
          + "@annotation(com.example.tracing.TracedEndpoint)")
  public Object traceEndpoint(ProceedingJoinPoint joinPoint) throws Throwable {
    MethodSignature methodSignature = (MethodSignature) joinPoint.getSignature();
    Method method = methodSignature.getMethod();

    TracedEndpoint annotation = method.getAnnotation(TracedEndpoint.class);
    if (annotation == null) {
      annotation = joinPoint.getTarget().getClass().getAnnotation(TracedEndpoint.class);
    }

    ServletRequestAttributes attrs =
        (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();

    String spanName;
    if (annotation != null && !annotation.name().isBlank()) {
      spanName = annotation.name();
    } else {
      // Use the HTTP request path as span name (e.g. GET /rag/02/query)
      if (attrs != null) {
        HttpServletRequest request = attrs.getRequest();
        spanName = request.getMethod() + " " + request.getRequestURI();
      } else {
        spanName = joinPoint.getTarget().getClass().getSimpleName() + "." + method.getName();
      }
    }

    Span span = tracer.spanBuilder(spanName).setSpanKind(SpanKind.SERVER).startSpan();

    try (Scope scope = span.makeCurrent()) {
      logger.debug(
          "Endpoint START: {} [traceId={}, spanId={}]",
          spanName,
          span.getSpanContext().getTraceId(),
          span.getSpanContext().getSpanId());

      span.setAttribute("component", "controller");
      span.setAttribute("method", method.getName());
      span.setAttribute("class", joinPoint.getTarget().getClass().getSimpleName());

      // --- Request payload logging ---
      String requestLog = spanName;
      if (attrs != null) {
        HttpServletRequest request = attrs.getRequest();
        String queryString = request.getQueryString();
        if (queryString != null && !queryString.isEmpty()) {
          requestLog = spanName + "?" + queryString;
        }
      }
      // Check for @RequestBody parameter
      Annotation[][] paramAnnotations = method.getParameterAnnotations();
      Object[] args = joinPoint.getArgs();
      for (int i = 0; i < paramAnnotations.length; i++) {
        for (Annotation paramAnnotation : paramAnnotations[i]) {
          if (paramAnnotation instanceof RequestBody) {
            String body =
                (args[i] instanceof String)
                    ? (String) args[i]
                    : objectMapper.writeValueAsString(args[i]);
            requestLog = requestLog + " [body=" + truncate(body) + "]";
            break;
          }
        }
      }
      logger.info("REQUEST: {}", requestLog);

      Object result = joinPoint.proceed();

      // --- Response payload logging ---
      String responseBody;
      if (result == null) {
        responseBody = "<null>";
      } else if (result instanceof String s) {
        responseBody = s;
      } else {
        responseBody = objectMapper.writeValueAsString(result);
      }
      logger.info("RESPONSE: {} -> {}", spanName, truncate(responseBody));

      span.setStatus(StatusCode.OK);
      logger.debug(
          "Endpoint END: {} [traceId={}, spanId={}]",
          spanName,
          span.getSpanContext().getTraceId(),
          span.getSpanContext().getSpanId());

      return result;
    } catch (Throwable ex) {
      span.setStatus(StatusCode.ERROR, ex.getMessage() != null ? ex.getMessage() : "Unknown error");
      span.recordException(ex);
      logger.error(
          "Endpoint ERROR: {} [traceId={}, spanId={}] - {}",
          spanName,
          span.getSpanContext().getTraceId(),
          span.getSpanContext().getSpanId(),
          ex.getMessage());
      throw ex;
    } finally {
      span.end();
    }
  }
}
