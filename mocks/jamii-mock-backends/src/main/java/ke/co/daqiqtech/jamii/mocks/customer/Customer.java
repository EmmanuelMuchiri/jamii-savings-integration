package ke.co.daqiqtech.jamii.mocks.customer;

/** A customer record shaped like a Kenyan bank's customer file. All data is synthetic. */
public record Customer(
        String customerId,
        String fullName,
        String nationalId,
        String phone,
        String email,
        String kycStatus,
        String branch) {

    Customer withId(String id) {
        return new Customer(id, fullName, nationalId, phone, email, kycStatus, branch);
    }
}
