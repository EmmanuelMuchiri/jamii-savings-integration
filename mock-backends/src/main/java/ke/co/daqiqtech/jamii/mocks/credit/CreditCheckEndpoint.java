package ke.co.daqiqtech.jamii.mocks.credit;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.ws.server.endpoint.annotation.Endpoint;
import org.springframework.ws.server.endpoint.annotation.PayloadRoot;
import org.springframework.ws.server.endpoint.annotation.RequestPayload;
import org.springframework.ws.server.endpoint.annotation.ResponsePayload;

/**
 * Mock credit-check engine (SOAP 1.1).
 * <p>Decision: debt-to-income % = (existingMonthlyDebt + requestedMonthlyInstalment) x 100 / monthlyIncome,
 * rounded half-up; ELIGIBLE when it is at most {@value #MAX_DTI_PERCENT}.</p>
 * <ul>
 *   <li>monthlyIncome &lt;= 0: soap:Client fault INVALID_INCOME</li>
 *   <li>customerId 6000: soap:Client fault CUSTOMER_BLACKLISTED</li>
 *   <li>customerId 5000: soap:Server fault (engine unavailable)</li>
 *   <li>customerId 5004: normal answer after a delay longer than MI's 10 s timeout</li>
 * </ul>
 */
@Endpoint
public class CreditCheckEndpoint {

    private static final Logger log = LoggerFactory.getLogger(CreditCheckEndpoint.class);

    public static final String NAMESPACE = "http://jamii.daqiqtech.co.ke/credit/v1";
    public static final int MAX_DTI_PERCENT = 40;

    static final String BLACKLISTED_ID = "6000";
    static final String SERVER_FAULT_ID = "5000";
    static final String SLOW_ID = "5004";

    private final long slowDelayMs;

    public CreditCheckEndpoint(@Value("${mocks.credit.slow-delay-ms:12000}") long slowDelayMs) {
        this.slowDelayMs = slowDelayMs;
    }

    @PayloadRoot(namespace = NAMESPACE, localPart = "CheckEligibilityRequest")
    @ResponsePayload
    public CheckEligibilityResponse checkEligibility(@RequestPayload CheckEligibilityRequest request)
            throws InterruptedException {

        String customerId = request.getCustomerId();
        if (SERVER_FAULT_ID.equals(customerId)) {
            log.warn("RULE customer={} -> soap:Server fault (MI should map to 502)", customerId);
            throw new CreditEngineException("Credit engine unavailable");
        }
        if (BLACKLISTED_ID.equals(customerId)) {
            log.warn("RULE customer={} -> soap:Client CUSTOMER_BLACKLISTED (MI should map to 422)", customerId);
            throw new EligibilityRejectedException("CUSTOMER_BLACKLISTED: Applicant is not eligible for credit");
        }
        BigDecimal income = request.getMonthlyIncome();
        if (income == null || income.signum() <= 0) {
            log.warn("REJECT customer={} -> soap:Client INVALID_INCOME (MI should map to 422)", customerId);
            throw new EligibilityRejectedException("INVALID_INCOME: Monthly income must be greater than zero");
        }
        if (SLOW_ID.equals(customerId)) {
            log.warn("RULE customer={} -> delaying {} ms (MI should time out and return 504)", customerId, slowDelayMs);
            Thread.sleep(slowDelayMs);
        }

        BigDecimal obligations = nz(request.getExistingMonthlyDebt()).add(nz(request.getRequestedMonthlyInstalment()));
        int dti = obligations.multiply(BigDecimal.valueOf(100))
                .divide(income, 0, RoundingMode.HALF_UP)
                .intValueExact();
        String decision = dti <= MAX_DTI_PERCENT ? "ELIGIBLE" : "NOT_ELIGIBLE";
        String referenceId = "CRD-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();

        log.info("DECISION customer={} reference={} dtiPercent={} max={} decision={}",
                customerId, referenceId, dti, MAX_DTI_PERCENT, decision);
        return new CheckEligibilityResponse(customerId, referenceId, decision, dti, MAX_DTI_PERCENT);
    }

    private static BigDecimal nz(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }
}
