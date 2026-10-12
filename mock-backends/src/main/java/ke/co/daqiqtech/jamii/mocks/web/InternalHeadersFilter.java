package ke.co.daqiqtech.jamii.mocks.web;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Adds internal headers to every response, as a real backend might.
 * MI's Common_HeaderHygiene sequence must strip these before responding to consumers.
 */
@Component
public class InternalHeadersFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        response.setHeader("X-Powered-By", "Jamii-Mock-Backends");
        response.setHeader("X-Internal-Trace", UUID.randomUUID().toString());
        response.setHeader("X-Internal-Node", "mock-node-01");
        chain.doFilter(request, response);
    }
}
