package ke.co.daqiqtech.jamii.mocks.web;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class LogMaskerTest {

    @Test
    void masksPiiInJson() {
        String json = "{\"customerId\":\"1001\",\"fullName\":\"Wanjiru Kamau\",\"nationalId\":\"28456123\","
                + "\"phone\":\"+254712345678\",\"kycStatus\":\"VERIFIED\",\"monthlyIncome\":120000}";
        String masked = LogMasker.body(json, true, 2000);
        assertThat(masked)
                .contains("\"customerId\":\"1001\"", "\"kycStatus\":\"VERIFIED\"")
                .contains("\"nationalId\":\"***\"", "\"phone\":\"***\"", "\"fullName\":\"***\"", "\"monthlyIncome\":\"***\"")
                .doesNotContain("28456123", "+254712345678", "Wanjiru", "120000");
    }

    @Test
    void masksAmountsInSoapXml() {
        String xml = "<cr:CheckEligibilityRequest>\n  <cr:customerId>1001</cr:customerId>\n"
                + "  <cr:monthlyIncome>120000</cr:monthlyIncome>\n</cr:CheckEligibilityRequest>";
        String masked = LogMasker.body(xml, true, 2000);
        assertThat(masked)
                .contains("<cr:customerId>1001</cr:customerId>", "<cr:monthlyIncome>***</cr:monthlyIncome>")
                .doesNotContain("120000", "\n");
    }

    @Test
    void masksCredentialHeaders() {
        assertThat(LogMasker.header("Authorization", "Bearer abc")).isEqualTo(LogMasker.MASK);
        assertThat(LogMasker.header("apikey", "xyz")).isEqualTo(LogMasker.MASK);
        assertThat(LogMasker.header("Content-Type", "text/xml")).isEqualTo("text/xml");
    }

    @Test
    void truncatesLongBodies() {
        assertThat(LogMasker.body("x".repeat(50), true, 10)).isEqualTo("xxxxxxxxxx...(truncated)");
    }

    @Test
    void maskingCanBeDisabled() {
        assertThat(LogMasker.body("{\"phone\":\"+254712345678\"}", false, 2000)).contains("+254712345678");
    }
}
