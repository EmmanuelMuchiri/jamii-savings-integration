package ke.co.daqiqtech.jamii.mocks;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/** Starts the full application and checks that both contracts are published. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class MockBackendsApplicationTests {

    @Autowired
    private TestRestTemplate rest;

    @Test
    void publishesOpenApiSpecForCustomers() {
        ResponseEntity<String> spec = rest.getForEntity("/v3/api-docs", String.class);
        assertThat(spec.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(spec.getBody()).contains("/customers/{customerId}", "Jamii Mock Backends");
    }

    @Test
    void publishesCreditCheckWsdl() {
        ResponseEntity<String> wsdl = rest.getForEntity("/ws/creditCheck.wsdl", String.class);
        assertThat(wsdl.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(wsdl.getBody()).contains("CheckEligibilityRequest", "CreditCheckPort");
    }

    @Test
    void servesSwaggerUi() {
        ResponseEntity<String> ui = rest.getForEntity("/swagger-ui/index.html", String.class);
        assertThat(ui.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
}
