package ke.co.daqiqtech.jamii.mocks.web;

import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Masks sensitive values before they reach the logs.
 * Headers: credentials and cookies. Bodies: customer PII and financial amounts,
 * in both JSON ("field": value) and XML (&lt;ns:field&gt;value&lt;/ns:field&gt;).
 */
public final class LogMasker {

    static final String MASK = "***";

    private static final Set<String> SENSITIVE_HEADERS = Set.of(
            "authorization", "proxy-authorization", "cookie", "set-cookie", "apikey", "x-api-key");

    private static final String FIELDS =
            "nationalId|phone|email|fullName|monthlyIncome|existingMonthlyDebt|requestedMonthlyInstalment";

    private static final Pattern JSON_FIELD =
            Pattern.compile("(\"(?:" + FIELDS + ")\"\\s*:\\s*)(\"[^\"]*\"|-?[0-9][0-9.]*)");
    private static final Pattern XML_FIELD =
            Pattern.compile("(<(?:[\\w-]+:)?(?:" + FIELDS + ")>)[^<]*(</)");
    private static final Pattern WHITESPACE = Pattern.compile("\\s*\\n\\s*");

    private LogMasker() {
    }

    public static String header(String name, String value) {
        return SENSITIVE_HEADERS.contains(name.toLowerCase(Locale.ROOT)) ? MASK : value;
    }

    /** Masks PII in a JSON or XML body and collapses it onto one line, truncated to maxChars. */
    public static String body(String body, boolean maskPii, int maxChars) {
        if (body == null || body.isBlank()) {
            return "";
        }
        String out = WHITESPACE.matcher(body.strip()).replaceAll(" ");
        if (maskPii) {
            out = JSON_FIELD.matcher(out).replaceAll("$1\"" + MASK + "\"");
            out = XML_FIELD.matcher(out).replaceAll("$1" + MASK + "$2");
        }
        return out.length() > maxChars ? out.substring(0, maxChars) + "...(truncated)" : out;
    }
}
