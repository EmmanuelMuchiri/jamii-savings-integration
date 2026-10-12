package ke.co.daqiqtech.jamii.mocks.customer;

import io.swagger.v3.oas.annotations.media.Schema;

/** A customer record shaped like a Kenyan bank's customer file. All data is synthetic. */
@Schema(description = "Customer record (synthetic data)")
public record Customer(
        @Schema(example = "1001") String customerId,
        @Schema(example = "Wanjiru Kamau") String fullName,
        @Schema(example = "28456123", description = "Kenyan national ID number") String nationalId,
        @Schema(example = "+254712345678") String phone,
        @Schema(example = "wanjiru.kamau@example.co.ke") String email,
        @Schema(example = "VERIFIED", allowableValues = {"VERIFIED", "PENDING", "REJECTED"}) String kycStatus,
        @Schema(example = "Nairobi CBD") String branch) {

    Customer withId(String id) {
        return new Customer(id, fullName, nationalId, phone, email, kycStatus, branch);
    }
}
