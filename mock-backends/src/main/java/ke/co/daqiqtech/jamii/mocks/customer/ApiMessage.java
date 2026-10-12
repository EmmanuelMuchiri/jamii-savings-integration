package ke.co.daqiqtech.jamii.mocks.customer;

import io.swagger.v3.oas.annotations.media.Schema;

/** Error body returned by the mock customer system (404 and 500). */
@Schema(description = "Error message from the customer system")
public record ApiMessage(@Schema(example = "Customer not found") String message) {
}
