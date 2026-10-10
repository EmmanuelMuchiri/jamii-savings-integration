package ke.co.daqiqtech.jamii.mocks.credit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class CreditCheckEndpointTest {

    private final CreditCheckEndpoint endpoint = new CreditCheckEndpoint(0);

    private static CheckEligibilityRequest request(String id, long income, long debt, long instalment) {
        return new CheckEligibilityRequest(id, BigDecimal.valueOf(income), BigDecimal.valueOf(debt), BigDecimal.valueOf(instalment));
    }

    @Test
    void eligibleAt33Percent() throws Exception {
        CheckEligibilityResponse r = endpoint.checkEligibility(request("1001", 120000, 15000, 25000));
        assertThat(r.getDebtToIncomePercent()).isEqualTo(33);
        assertThat(r.getDecision()).isEqualTo("ELIGIBLE");
        assertThat(r.getReferenceId()).startsWith("CRD-");
    }

    @Test
    void notEligibleAt50Percent() throws Exception {
        CheckEligibilityResponse r = endpoint.checkEligibility(request("1002", 50000, 15000, 10000));
        assertThat(r.getDebtToIncomePercent()).isEqualTo(50);
        assertThat(r.getDecision()).isEqualTo("NOT_ELIGIBLE");
    }

    @Test
    void zeroIncomeIsClientFault() {
        assertThatThrownBy(() -> endpoint.checkEligibility(request("1001", 0, 15000, 25000)))
                .isInstanceOf(EligibilityRejectedException.class)
                .hasMessageStartingWith("INVALID_INCOME");
    }

    @Test
    void blacklistedCustomerIsClientFault() {
        assertThatThrownBy(() -> endpoint.checkEligibility(request("6000", 120000, 0, 0)))
                .isInstanceOf(EligibilityRejectedException.class)
                .hasMessageStartingWith("CUSTOMER_BLACKLISTED");
    }

    @Test
    void engineFailureIsServerFault() {
        assertThatThrownBy(() -> endpoint.checkEligibility(request("5000", 120000, 0, 0)))
                .isInstanceOf(CreditEngineException.class);
    }
}
