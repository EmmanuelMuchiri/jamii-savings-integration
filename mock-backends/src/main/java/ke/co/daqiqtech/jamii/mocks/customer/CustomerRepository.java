package ke.co.daqiqtech.jamii.mocks.customer;

import java.util.Map;
import java.util.Optional;
import org.springframework.stereotype.Repository;

/** In-memory customer data. Synthetic records only. */
@Repository
public class CustomerRepository {

    private static final Map<String, Customer> CUSTOMERS = Map.of(
            "1001", new Customer("1001", "Wanjiru Kamau", "28456123", "+254712345678", "wanjiru.kamau@example.co.ke", "VERIFIED", "Nairobi CBD"),
            "1002", new Customer("1002", "Otieno Ochieng", "30981245", "+254722987654", "otieno.ochieng@example.co.ke", "VERIFIED", "Kisumu"),
            "1003", new Customer("1003", "Amina Hassan", "27654310", "+254733112233", "amina.hassan@example.co.ke", "PENDING", "Mombasa"),
            "1004", new Customer("1004", "Kiprono Kirui", "31200457", "+254701556677", "kiprono.kirui@example.co.ke", "VERIFIED", "Eldoret"),
            "1005", new Customer("1005", "Njeri Mwangi", "29873456", "+254745889900", "njeri.mwangi@example.co.ke", "REJECTED", "Nakuru"));

    public Optional<Customer> findById(String customerId) {
        return Optional.ofNullable(CUSTOMERS.get(customerId));
    }
}
