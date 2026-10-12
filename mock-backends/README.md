# Jamii Mock Backends

Spring Boot service that stands in for Jamii Savings' **customer system (REST/JSON)** and **credit-check engine (SOAP 1.1)**. It lives in `mock-backends/` of the integration repository and runs as the `mock-backends` service of the root `docker-compose.yml`; WSO2 MI calls it as its backend. It can also be deployed on its own.

- Java 21, Spring Boot 3.5, Maven, packaged as an executable jar
- Docker image built with a multi-stage Dockerfile; run with its own `docker-compose.yml`
- All data is synthetic
- Structured request/response logging with correlation IDs and PII masking
- Swagger UI for the REST endpoint; WSDL for the SOAP endpoint

## Endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /customers/{customerId}` | Customer record (REST/JSON) |
| `POST /ws` (`CheckEligibilityRequest`) | Credit check (SOAP 1.1) |
| `GET /ws/creditCheck.wsdl` | WSDL |
| `GET /swagger-ui.html` | Swagger UI for the customer REST API |
| `GET /v3/api-docs` | OpenAPI 3 spec for the customer REST API |
| `GET /actuator/health` | Health check |

Every response carries `Server`, `X-Powered-By` and `X-Internal-*` headers, as a real backend might. MI must strip them.

## Test rules

**Customers**

| customerId | Response | MI maps to |
| --- | --- | --- |
| 1001-1005 | 200 with record (national ID, +254 phone, KYC status, branch) | 200 |
| 9999 (or any unknown) | 404 | 404 CUSTOMER_NOT_FOUND |
| 5000 | 500 | 502 BAD_GATEWAY |
| 5004 | 200 after 7 s | 504 BACKEND_TIMEOUT (MI timeout 5 s) |

**Credit check** (DTI % = (existingMonthlyDebt + requestedMonthlyInstalment) x 100 / monthlyIncome; ELIGIBLE at 40 or less)

| Input | Response | MI maps to |
| --- | --- | --- |
| Normal values | `CheckEligibilityResponse` with decision and DTI | 200 |
| monthlyIncome 0 | soap:Client `INVALID_INCOME` | 422 ELIGIBILITY_REJECTED |
| customerId 6000 | soap:Client `CUSTOMER_BLACKLISTED` | 422 ELIGIBILITY_REJECTED |
| customerId 5000 | soap:Server | 502 BAD_GATEWAY |
| customerId 5004 | answer after 12 s | 504 BACKEND_TIMEOUT (MI timeout 10 s) |

Delays are configurable: `MOCKS_CUSTOMER_SLOWDELAYMS`, `MOCKS_CREDIT_SLOWDELAYMS`.

## Logging

Every call (except `/actuator`) is logged by `RequestResponseLoggingFilter`, one line per stage, each tagged with the correlation ID. The service reuses the caller's `X-Correlation-ID` (MI sends one), or generates one, and echoes it in the response.

| Line | Contents |
| --- | --- |
| `REQUEST_IN` | method, path and query, client IP (first `X-Forwarded-For` hop, then `X-Real-IP`, then socket), remote address and port, request headers |
| `REQUEST_BODY` | request body on one line (SOAP and JSON) |
| `RESPONSE_OUT` | status, duration in ms, response headers, response body; logged at WARN for 4xx and ERROR for 5xx |
| `LOOKUP` / `DECISION` / `RULE` / `REJECT` | business outcome: customer found or not, credit decision, or which test rule fired |

Credentials (`Authorization`, `apikey`, cookies) are masked, and so are PII and amounts in bodies (`fullName`, `nationalId`, `phone`, `email`, `monthlyIncome`, `existingMonthlyDebt`, `requestedMonthlyInstalment`). Settings: `MOCKS_LOGGING_MASKPII` (default `true`) and `MOCKS_LOGGING_MAXBODYCHARS` (default `2000`).

```text
2026-10-09T10:15:30.120+03:00 INFO  [5b1f8c2e-6a0d-4f7e-9b3a-2c1d0e9f8a77] jamii.http               REQUEST_IN  GET /customers/1001 client=172.20.0.5 remote=172.20.0.5:51234 headers={host=jamii-mock-backends:8080, x-correlation-id=5b1f8c2e-..., accept=application/json}
2026-10-09T10:15:30.124+03:00 INFO  [5b1f8c2e-6a0d-4f7e-9b3a-2c1d0e9f8a77] c.CustomerController     LOOKUP customer=1001 -> found (kycStatus=VERIFIED, branch=Nairobi CBD)
2026-10-09T10:15:30.131+03:00 INFO  [5b1f8c2e-6a0d-4f7e-9b3a-2c1d0e9f8a77] jamii.http               RESPONSE_OUT GET /customers/1001 status=200 durationMs=11 headers={X-Correlation-ID=5b1f8c2e-..., X-Powered-By=Jamii-Mock-Backends, ...} body={"customerId":"1001","fullName":"***","nationalId":"***","phone":"***","email":"***","kycStatus":"VERIFIED","branch":"Nairobi CBD"}
```

Follow the logs with `docker compose logs -f mock-backends`.

## Build and run

```bash
# jar only
mvn clean package
java -jar target/jamii-mock-backends.jar

# as part of the whole stack (from the repository root)
docker compose up -d --build

# on its own (from mock-backends/)
docker compose up -d --build
curl http://localhost:8081/customers/1001
curl http://localhost:8081/ws/creditCheck.wsdl
# Swagger UI: http://localhost:8081/swagger-ui.html
```

In the stack, MI reaches it at `http://jamii-mock-backends:8080` (a network alias). When deployed elsewhere, point MI's `CUSTOMER_BACKEND_URL` and `CREDIT_BACKEND_URL` at the deployed host.

## Sample SOAP request

```xml
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:cr="http://jamii.daqiqtech.co.ke/credit/v1">
  <soapenv:Body>
    <cr:CheckEligibilityRequest>
      <cr:customerId>1001</cr:customerId>
      <cr:monthlyIncome>120000</cr:monthlyIncome>
      <cr:existingMonthlyDebt>15000</cr:existingMonthlyDebt>
      <cr:requestedMonthlyInstalment>25000</cr:requestedMonthlyInstalment>
    </cr:CheckEligibilityRequest>
  </soapenv:Body>
</soapenv:Envelope>
```

```bash
curl -s -H 'Content-Type: text/xml' --data @request.xml http://localhost:8081/ws
```
