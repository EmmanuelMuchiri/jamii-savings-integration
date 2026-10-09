package ke.co.daqiqtech.jamii.mocks.customer;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Mock customer system.
 * <ul>
 *   <li>1001-1005: 200 with a customer record</li>
 *   <li>5000: 500 (MI maps to 502 BAD_GATEWAY)</li>
 *   <li>5004: 200 after a delay longer than MI's 5 s timeout (MI maps to 504)</li>
 *   <li>anything else (e.g. 9999): 404 (MI maps to 404 CUSTOMER_NOT_FOUND)</li>
 * </ul>
 */
@RestController
@RequestMapping("/customers")
@Tag(name = "Customers", description = "Mock customer system (REST/JSON). Test IDs trigger each error path.")
public class CustomerController {

    private static final Logger log = LoggerFactory.getLogger(CustomerController.class);

    static final String SERVER_ERROR_ID = "5000";
    static final String SLOW_ID = "5004";

    private final CustomerRepository repository;
    private final long slowDelayMs;

    public CustomerController(CustomerRepository repository,
                              @Value("${mocks.customer.slow-delay-ms:7000}") long slowDelayMs) {
        this.repository = repository;
        this.slowDelayMs = slowDelayMs;
    }

    @Operation(
            summary = "Get a customer by ID",
            description = "1001-1005 return a record. 9999 (or any unknown ID) returns 404. "
                    + "5000 returns 500. 5004 answers after 7 s, longer than MI's 5 s timeout.")
    @ApiResponse(responseCode = "200", description = "Customer found",
            content = @Content(schema = @Schema(implementation = Customer.class)))
    @ApiResponse(responseCode = "404", description = "Unknown customer (try 9999)",
            content = @Content(schema = @Schema(implementation = ApiMessage.class),
                    examples = @ExampleObject(value = "{\"message\":\"Customer not found\"}")))
    @ApiResponse(responseCode = "500", description = "Simulated customer-system failure (try 5000)",
            content = @Content(schema = @Schema(implementation = ApiMessage.class),
                    examples = @ExampleObject(value = "{\"message\":\"Internal error in customer system\"}")))
    @GetMapping("/{customerId}")
    public ResponseEntity<?> getCustomer(
            @Parameter(description = "Customer ID: 1001-1005, 9999 (404), 5000 (500), 5004 (slow)", example = "1001")
            @PathVariable String customerId) throws InterruptedException {
        if (SERVER_ERROR_ID.equals(customerId)) {
            log.warn("RULE customer={} -> simulated 500 (MI should map to 502)", customerId);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new ApiMessage("Internal error in customer system"));
        }
        if (SLOW_ID.equals(customerId)) {
            log.warn("RULE customer={} -> delaying {} ms (MI should time out and return 504)", customerId, slowDelayMs);
            Thread.sleep(slowDelayMs);
            return ResponseEntity.ok(repository.findById("1004").orElseThrow().withId(SLOW_ID));
        }
        return repository.findById(customerId)
                .<ResponseEntity<?>>map(c -> {
                    log.info("LOOKUP customer={} -> found (kycStatus={}, branch={})", customerId, c.kycStatus(), c.branch());
                    return ResponseEntity.ok(c);
                })
                .orElseGet(() -> {
                    log.info("LOOKUP customer={} -> not found (404)", customerId);
                    return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiMessage("Customer not found"));
                });
    }
}
