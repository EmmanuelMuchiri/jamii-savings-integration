# Jamii Savings Integration Platform

Three integrations for the fictional Jamii Savings bank, built on **WSO2 Micro Integrator**, exposed and governed through **WSO2 API Manager** (both self-managed), and built and deployed by a single **Jenkins** pipeline.

| API | Method and path | Backend |
| --- | --- | --- |
| Account Balance | `GET /accounts/{accountNumber}/balance` | H2 database via MI Data Service |
| Customer Profile | `GET /customers/{customerId}` | Beeceptor mock REST endpoint |
| Loan Eligibility | `POST /loans/eligibility` | DNE Online Calculator SOAP service |

> Status: work in progress. Sections marked TODO are completed during the build.

## Architecture

![High-level design](docs/diagrams/hld.png)

![Architecture](docs/diagrams/architecture.png)

Full design: [Solution Design Document](docs/Jamii_Savings_Solution_Design_v1.2.pdf) · Requirements: [BRD](docs/Jamii_Savings_BRD_v1.2.pdf)

## Backend choices

**Customer API: Beeceptor.** The Customer API fronts a Beeceptor mock endpoint whose records are shaped like a Kenyan bank's customer file (national ID, +254 phone, KYC status), so real-world PII goes through the masking layer. Its rules return 404, 500 and a 7-second delay on demand, so every error path is exercised against the backend itself. The free tier has a request cap, so the rules are exported to `mocks/beeceptor-rules.json` and mirrored in WireMock; CI uses WireMock, and Beeceptor is used for the live demo.

**Loan Eligibility API: DNE Online Calculator (SOAP).** `Divide` computes the debt-to-income ratio: (existing monthly debt + requested instalment) × 100 ÷ monthly income, as a whole percent. The applicant is eligible at 40% or less. Debt-to-income is a real lending affordability test, so the SOAP call does meaningful work. An income of 0 produces a genuine SOAP divide-by-zero fault, which is mapped to `422 ELIGIBILITY_REJECTED`; any other fault maps to `502 BAD_GATEWAY`. SOAP XML never reaches the client.

## Architecture decisions and trade-offs

TODO (summarise ADRs 01-14 from the design doc).

## Throttling tiers

TODO: Loan Eligibility uses the custom `LoanCheck-10PerMin` tier because each call depends on a slow external SOAP service with no SLA.

## How to run locally

Prerequisites: Docker with 10-12 GB RAM, JDK 21, Maven 3.9, apictl, curl, jq.

```bash
cp .env.example .env                 # set passwords and versions
# download the WSO2 zips into dist/ (see dist/README.md)
docker compose --profile core up -d --build
```

TODO: apictl import steps, token generation, sample calls.

## Developer Portal: discover and subscribe

TODO (steps from design doc §7).

## Assumptions

TODO.

## What I would do differently with more time

TODO.

## Demo recording

TODO: link to the 5-minute recording.
