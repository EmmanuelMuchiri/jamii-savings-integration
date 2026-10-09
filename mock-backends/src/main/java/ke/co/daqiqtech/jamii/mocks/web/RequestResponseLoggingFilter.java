package ke.co.daqiqtech.jamii.mocks.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingRequestWrapper;
import org.springframework.web.util.ContentCachingResponseWrapper;

/**
 * Logs every call to the mock backends: the incoming request (method, path, client IP,
 * headers) and the outgoing response (status, duration, headers, request and response bodies).
 * <p>Correlation: reuses the caller's X-Correlation-ID (MI sends one) or generates one,
 * puts it in the MDC so every log line carries it, and echoes it in the response.</p>
 * <p>Sensitive headers are masked and PII in bodies is masked (see {@link LogMasker}).
 * Actuator, Swagger UI and OpenAPI calls are not logged.</p>
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestResponseLoggingFilter extends OncePerRequestFilter {

    static final String CORRELATION_HEADER = "X-Correlation-ID";
    static final String MDC_KEY = "correlationId";

    private static final Logger log = LoggerFactory.getLogger("jamii.http");

    private final boolean maskPii;
    private final int maxBodyChars;

    public RequestResponseLoggingFilter(@Value("${mocks.logging.mask-pii:true}") boolean maskPii,
                                        @Value("${mocks.logging.max-body-chars:2000}") int maxBodyChars) {
        this.maskPii = maskPii;
        this.maxBodyChars = maxBodyChars;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String uri = request.getRequestURI();
        return uri.startsWith("/actuator") || uri.startsWith("/swagger-ui") || uri.startsWith("/v3/api-docs");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        String correlationId = StringUtils.hasText(request.getHeader(CORRELATION_HEADER))
                ? request.getHeader(CORRELATION_HEADER)
                : UUID.randomUUID().toString();
        MDC.put(MDC_KEY, correlationId);
        response.setHeader(CORRELATION_HEADER, correlationId);

        ContentCachingRequestWrapper req = new ContentCachingRequestWrapper(request, maxBodyChars * 4);
        ContentCachingResponseWrapper res = new ContentCachingResponseWrapper(response);
        String target = request.getMethod() + " " + request.getRequestURI()
                + (request.getQueryString() != null ? "?" + request.getQueryString() : "");

        log.info("REQUEST_IN  {} client={} remote={}:{} headers={}",
                target, clientIp(request), request.getRemoteAddr(), request.getRemotePort(), requestHeaders(request));

        long start = System.nanoTime();
        try {
            chain.doFilter(req, res);
        } finally {
            long elapsedMs = (System.nanoTime() - start) / 1_000_000;
            String requestBody = LogMasker.body(
                    new String(req.getContentAsByteArray(), charset(req.getCharacterEncoding())), maskPii, maxBodyChars);
            String responseBody = LogMasker.body(
                    new String(res.getContentAsByteArray(), charset(res.getCharacterEncoding())), maskPii, maxBodyChars);

            if (!requestBody.isEmpty()) {
                log.info("REQUEST_BODY {} body={}", target, requestBody);
            }
            int status = res.getStatus();
            String line = "RESPONSE_OUT {} status={} durationMs={} headers={} body={}";
            Object[] args = {target, status, elapsedMs, responseHeaders(res), responseBody};
            if (status >= 500) {
                log.error(line, args);
            } else if (status >= 400) {
                log.warn(line, args);
            } else {
                log.info(line, args);
            }
            try {
                res.copyBodyToResponse();
            } finally {
                MDC.remove(MDC_KEY);
            }
        }
    }

    /** Original client IP: first X-Forwarded-For hop, then X-Real-IP, then the socket address. */
    static String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (StringUtils.hasText(forwarded)) {
            return forwarded.split(",")[0].trim();
        }
        String realIp = request.getHeader("X-Real-IP");
        return StringUtils.hasText(realIp) ? realIp.trim() : request.getRemoteAddr();
    }

    private static Map<String, String> requestHeaders(HttpServletRequest request) {
        Map<String, String> headers = new LinkedHashMap<>();
        for (String name : Collections.list(request.getHeaderNames())) {
            headers.put(name, LogMasker.header(name, String.join(",", Collections.list(request.getHeaders(name)))));
        }
        return headers;
    }

    private static Map<String, String> responseHeaders(HttpServletResponse response) {
        Map<String, String> headers = new LinkedHashMap<>();
        for (String name : new ArrayList<>(response.getHeaderNames())) {
            List<String> values = new ArrayList<>(response.getHeaders(name));
            headers.put(name, LogMasker.header(name, String.join(",", values)));
        }
        return headers;
    }

    private static Charset charset(String encoding) {
        try {
            return encoding != null ? Charset.forName(encoding) : StandardCharsets.UTF_8;
        } catch (RuntimeException e) {
            return StandardCharsets.UTF_8;
        }
    }
}
