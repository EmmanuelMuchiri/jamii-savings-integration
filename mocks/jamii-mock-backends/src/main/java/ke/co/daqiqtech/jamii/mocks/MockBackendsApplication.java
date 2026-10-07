package ke.co.daqiqtech.jamii.mocks;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Mock backends for the Jamii Savings integration platform.
 * REST:  GET  /customers/{customerId}
 * SOAP:  POST /ws  (CheckEligibility), WSDL at /ws/creditCheck.wsdl
 */
@SpringBootApplication
public class MockBackendsApplication {
    public static void main(String[] args) {
        SpringApplication.run(MockBackendsApplication.class, args);
    }
}
