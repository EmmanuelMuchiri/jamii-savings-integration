package ke.co.daqiqtech.jamii.mocks.credit;

import jakarta.xml.bind.annotation.XmlRootElement;
import jakarta.xml.bind.annotation.XmlType;

@XmlRootElement(name = "CheckEligibilityResponse")
@XmlType(propOrder = {"customerId", "referenceId", "decision", "debtToIncomePercent", "maxAllowedPercent"})
public class CheckEligibilityResponse {

    private String customerId;
    private String referenceId;
    private String decision;
    private int debtToIncomePercent;
    private int maxAllowedPercent;

    public CheckEligibilityResponse() {
    }

    public CheckEligibilityResponse(String customerId, String referenceId, String decision,
                                    int debtToIncomePercent, int maxAllowedPercent) {
        this.customerId = customerId;
        this.referenceId = referenceId;
        this.decision = decision;
        this.debtToIncomePercent = debtToIncomePercent;
        this.maxAllowedPercent = maxAllowedPercent;
    }

    public String getCustomerId() { return customerId; }
    public String getReferenceId() { return referenceId; }
    public String getDecision() { return decision; }
    public int getDebtToIncomePercent() { return debtToIncomePercent; }
    public int getMaxAllowedPercent() { return maxAllowedPercent; }
}
