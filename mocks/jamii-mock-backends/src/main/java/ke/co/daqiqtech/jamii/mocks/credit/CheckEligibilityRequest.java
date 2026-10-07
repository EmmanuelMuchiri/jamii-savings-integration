package ke.co.daqiqtech.jamii.mocks.credit;

import jakarta.xml.bind.annotation.XmlRootElement;
import jakarta.xml.bind.annotation.XmlType;
import java.math.BigDecimal;

@XmlRootElement(name = "CheckEligibilityRequest")
@XmlType(propOrder = {"customerId", "monthlyIncome", "existingMonthlyDebt", "requestedMonthlyInstalment"})
public class CheckEligibilityRequest {

    private String customerId;
    private BigDecimal monthlyIncome;
    private BigDecimal existingMonthlyDebt;
    private BigDecimal requestedMonthlyInstalment;

    public CheckEligibilityRequest() {
    }

    public CheckEligibilityRequest(String customerId, BigDecimal monthlyIncome,
                                   BigDecimal existingMonthlyDebt, BigDecimal requestedMonthlyInstalment) {
        this.customerId = customerId;
        this.monthlyIncome = monthlyIncome;
        this.existingMonthlyDebt = existingMonthlyDebt;
        this.requestedMonthlyInstalment = requestedMonthlyInstalment;
    }

    public String getCustomerId() { return customerId; }
    public BigDecimal getMonthlyIncome() { return monthlyIncome; }
    public BigDecimal getExistingMonthlyDebt() { return existingMonthlyDebt; }
    public BigDecimal getRequestedMonthlyInstalment() { return requestedMonthlyInstalment; }
}
