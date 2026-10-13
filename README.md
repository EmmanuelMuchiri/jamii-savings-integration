# Jamii Savings Integration Platform

Three integrations for the fictional Jamii Savings bank, built on **WSO2 Micro Integrator**, exposed and governed through **WSO2 API Manager** (both self-managed), and built and deployed by a single **Jenkins** pipeline.

| API | Method and path | Backend |
| --- | --- | --- |
| Account Balance | `GET /accounts/{accountNumber}/balance` | H2 database via MI Data Service |
| Customer Profile | `GET /customers/{customerId}` | Jamii mock customer service (Spring Boot, REST) |
| Loan Eligibility | `POST /loans/eligibility` | Jamii mock credit-check service (Spring Boot, SOAP) |

## Live environment (VPS)

Self-hosted on a Contabo VPS behind nginx (TLS at nginx, one subdomain per service, every container bound to `127.0.0.1`). **Status: deploying 12 Oct 2026.** Steps: [VPS deployment guide](docs/VPS-DEPLOYMENT.md). 

| Service | URL | Access |
| --- | --- | --- |
| API gateway | https://api.jamii.daqiqtech.co.ke | Public (OAuth2 or API key) |
| Developer Portal | https://portal.jamii.daqiqtech.co.ke/devportal | Public; self sign-up, or a demo login shared separately |
| Publisher / Admin | https://portal.jamii.daqiqtech.co.ke/publisher | Public + login |
| Jenkins | https://jenkins.jamii.daqiqtech.co.ke | Public + login |


Example: `curl -H "Authorization: Bearer <token>" https://api.jamii.daqiqtech.co.ke/jamii/accounts/v1/0123456789/balance`

## Quick start: everything, end to end

Prerequisites: Docker Desktop (Compose 2.24 or later) with 10–12 GB of memory.

1. **Clone the repository and check out `stage`:**
   ```bash
   git clone https://github.com/EmmanuelMuchiri/jamii-savings-integration.git
   cd jamii-savings-integration && git checkout stage
   ```
2. **Download the WSO2 distributions** into `dist/`: **Micro Integrator 4.3.0** (`wso2mi-4.3.0.zip`) and **API Manager 4.4.0** (`wso2am-4.4.0.zip`). Then record their checksums:
   ```bash
   cd dist && sha256sum wso2mi-4.3.0.zip wso2am-4.4.0.zip > checksums.txt && cd ..
   ```
3. **Create the settings file:** `cp .env.example .env`
4. **Start Jenkins:**
   ```bash
   docker compose --profile ci up -d --build jenkins
   ```
5. **Open Jenkins** at http://127.0.0.1:8090 and sign in with **admin / admin**.
6. Open the **jamii-savings-integration** job and click **Build** (or **Build with Parameters → Build**). The first run takes about 15 minutes: it validates, tests, builds every image, deploys MI and API Manager, publishes the APIs, and runs 33 end-to-end checks.

When the build is green:

| | |
| --- | --- |
| Developer Portal | https://localhost:9443/devportal |
| Publisher | https://localhost:9443/publisher |
| Gateway | https://localhost:8243 |
| Mock backends (Swagger UI) | http://localhost:8081/swagger-ui.html |

API Manager uses a self-signed certificate locally, so accept the browser warning. Demo credentials (OAuth keys and an API key) are in `.apim-demo.env`; the Postman collection and a ready-made environment are in `docs/postman/`.

## Architecture

![Architecture](docs/diagrams/architecture.png)

Consumers call **API Manager** (security, throttling, the gateway policy, the Developer Portal). The gateway forwards to **Micro Integrator**, which does the integration work: a Data Service on H2 for balances, a managed proxy for customer profiles, and JSON-to-SOAP mediation for loan eligibility. MI is never exposed directly. **Jenkins** validates, tests, builds and deploys both layers as one release.

| Diagram | |
| --- | --- |
| [High-level design](docs/diagrams/hld.png) | Layers, runtimes and versions |
| [Edge topology](docs/diagrams/edge-topology.png) | nginx subdomains, what is public and what is allowlisted |
| [Loan eligibility sequence](docs/diagrams/loan-sequence.png) | JSON in, SOAP to the credit engine, fault mapping, JSON out |
| [Pipeline](docs/diagrams/pipeline.png) | Jenkins stages, approval gate and rollback |

**Developer Portal** (Jamii-branded API Manager 4.4):

![Developer Portal](docs/screenshots/devportal-apis.png)

**Jenkins** (one pipeline for all three APIs):

![Jenkins stage view](docs/screenshots/jenkins-stage-view.png)

Full design: [Solution Design Document](docs/Jamii_Savings_Solution_Design_v1.5.pdf) · Requirements: [BRD](docs/Jamii_Savings_BRD_v1.5.pdf) · WhiteBoarding: [White Boarding](docs/screenshots/white-boarding.png) · Plan: [Jira plan](docs/screenshots/jira.png)

## Backend choices

Both non-database backends are provided by the **mock backends** in `mock-backends/`: a Spring Boot service (JDK 21, Maven, executable jar) with its own Dockerfile. It runs as the `mock-backends` service of this stack, and can also be deployed on its own with `mock-backends/docker-compose.yml`. Swagger UI: http://localhost:8081/swagger-ui.html

**Why a self-built mock instead of an existing public API.** The brief suggests existing public mock and SOAP test services. I chose to build the backends because the integration layer's value is in how it handles real behaviour, and public services cannot produce that behaviour on demand:

- **Bank-shaped data.** Customer records carry a national ID, +254 phone number and KYC status, so the masking layer is tested on the PII a bank actually holds.
- **Every failure mode, deterministically.** Specific IDs return 404, 500, a SOAP client fault, a SOAP server fault, or a delay longer than MI's timeout. Every error mapping in the BRD can be demonstrated live.
- **Leaky headers.** Responses include `Server`, `X-Powered-By` and `X-Internal-*` headers, so header stripping is proven, not assumed.
- **A meaningful SOAP contract.** `CheckEligibility` (XSD and WSDL at `/ws/creditCheck.wsdl`) is a credit-check operation, not a calculator repurposed as one.
- **No third-party outages or quotas** during the pipeline run or the recording.

The trade-off is one more service to build and run, and a deliberate departure from the "existing public" wording, which is why it is explained here.

| Backend | Endpoint | Rules |
| --- | --- | --- |
| Customer system (REST) | `GET /customers/{id}` | 1001-1005: 200; 9999: 404; 5000: 500; 5004: 7 s delay |
| Credit-check engine (SOAP 1.1) | `POST /ws` (`CheckEligibility`) | normal: decision and debt-to-income %; income 0 or customer 6000: soap:Client; customer 5000: soap:Server; customer 5004: 12 s delay |

## Architecture decisions and trade-offs

The design document records 22 decisions (§ ADR log). The ones that shape the build most:

| Decision | Trade-off |
| --- | --- |
| Self-managed WSO2 (MI 4.3.0 and APIM 4.4.0 on JDK 17), images built from the downloaded distributions | Full control of versions and configuration; more to build and patch than vendor images |
| H2 in its own container (server mode) | Stopping it demonstrates the 503 `DB_UNAVAILABLE` path live |
| Self-built Spring Boot mock backends | Deterministic data, faults and delays; one more service, and a departure from "existing public" (see Backend choices) |
| One error envelope for every API, whatever the backend | Consumers handle one shape; MI maps every backend fault to it |
| Two-layer log masking: whitelisted log fields plus a log-format rule masking any 10+ digit number | No Java code, and it also covers MI's own internal logs; rule-based rather than field-aware |
| API definitions as apictl projects in Git, published by a one-shot `apim-init` container | Reproducible from nothing in one `docker compose up`; one more image |
| API Product at an explicit version 1, as the default version | Found by experiment: the implicit 1.0.0 had no default route and its versioned route failed authentication |
| One application per access model (`jamii-channel` for the product, `jamii-mobile` for individual APIs) | Two sets of keys; subscriptions never overlap |
| Validate everything before deploying anything; roll the whole release back on failure | A release is one set of images with one tag, so rollback restores MI and APIM together |
| Pipeline tests run against the deployed stack (mock JUnit, MI smoke, gateway checks) instead of MI unit tests | Tests hit real faults, timeouts and the database; they run after deployment rather than before |

## Throttling tiers

| API | Tiers offered | Why |
| --- | --- | --- |
| Account Balance | Gold, Unlimited | Fast, local database lookup |
| Customer Profile | Gold, Unlimited | Read-only lookup against the customer system |
| Loan Eligibility | **LoanCheck10PerMin** (custom), Gold | Each call depends on an external credit engine with no SLA and up to 10 s latency, so it gets a tight, custom quota: 10 requests a minute per subscription. Over the quota the gateway returns 429. |
| Retail Banking (product) | Gold | One subscription for Jamii's own channel apps |

## Developer Portal: discover and subscribe

How a developer at a partner or a Jamii channel team starts using the APIs:

**1. Sign in** at the Developer Portal with your account.

![Sign in](docs/screenshots/subscribe-1-sign-in.png)

**2. Find an API.** The home page lists Account Balance, Customer Profile, Loan Eligibility and the **Jamii Retail Banking** product. Each has an overview, the OpenAPI definition, and its business plans. Channel apps should take the product (one subscription, all three APIs); partners subscribe to individual APIs.

![API overview](docs/screenshots/subscribe-2-api-overview.png)

**3. Create an application** under **Applications → Add New Application** (name, description, application-level quota).

![Create application](docs/screenshots/subscribe-3-application.png)

**4. Subscribe.** In the application, open **Subscriptions → Subscribe APIs**, choose the API or product and a business plan (Gold, or `LoanCheck10PerMin` for Loan Eligibility).

![Subscribe](docs/screenshots/subscribe-4-subscribe.png)

**5. Get credentials.** Under **Production Keys → Generate Keys** for OAuth2 (Account Balance, Loan Eligibility, the product), or **API Key → Generate Key** for Customer Profile.

![Generate keys](docs/screenshots/subscribe-5-keys.png)

**6. Try it.** Use **Try Out** on the API page, or call the gateway yourself:

![Try out](docs/screenshots/subscribe-6-try-out.png)

```bash
TOKEN=$(curl -sk -u "<consumer key>:<consumer secret>" -d grant_type=client_credentials https://localhost:9443/oauth2/token | jq -r .access_token)
curl -sk -H "Authorization: Bearer $TOKEN" https://localhost:8243/jamii/retail-banking/0123456789/balance
```

Every response carries an `X-Correlation-ID` (send your own to trace a call end to end), and every error uses the same body: `{"error":{"code","message","httpStatus","details"},"requestId","timestamp"}`.

## Assumptions

- **Synthetic data only.** All accounts, customers and income figures are invented; no real customer data is used anywhere.
- **Backends are mocks.** The customer system and the credit engine are Jamii-owned mocks whose contracts (REST JSON, SOAP `CheckEligibility`) stand in for real systems; MI talks to them exactly as it would to the real ones.
- **Single-node, all-in-one WSO2.** One MI and one API Manager (gateway, key manager, portals together) are enough for the assignment; production would separate and cluster them.
- **H2 stands in for the core banking database.** It is recreated from schema and seed on every start.
- **Kenyan shillings and +254 numbers.** Currency is KES; IDs and phone formats are Kenyan.
- **Loan rule.** Eligible when total monthly debt, including the new instalment, is at most 40% of monthly income.
- **Secrets.** Kept in `.env` locally and in Jenkins credentials; a production setup would use a secrets manager.
- **Dev and prod.** The pipeline deploys to dev; prod is an approval-gated dry run, since there is one host.
- **Free, local tooling.** Self-signed certificates locally; TLS at nginx on the VPS.

## What I would do differently with more time

- **Monitoring with ELK.** The design is ready (§ observability): Filebeat ships MI, API Manager and mock-backend logs to Logstash, which re-masks PII as a second safeguard, into Elasticsearch, with Kibana dashboards for traffic, errors by code, latency and throttling, searchable by correlation ID. It is the next piece I would build.
- **MI Dashboard.** A Dashboard container is ready (`--profile dashboard`), but the only Dashboard version available to me without a business email, 4.2.0, does not register MI 4.3.0 nodes. With the matching 4.3.0 Dashboard it would start with no other changes; until then MI is inspected through its management API (Postman folder 3).
- **Alerting.** Alerts on error rate, 5xx from the credit engine, and 429 spikes, wired to the team's channel.
- **MI unit tests and a CAR build.** Add MI unit-test suites with mocked endpoints and package a `.car` with the WSO2 Maven plugins, alongside the image.
- **Production topology.** Separate gateway, key manager and portals; two MI nodes behind a load balancer; a production database instead of API Manager's embedded one.
- **Secrets management.** Move passwords and keys into a vault and rotate them; add a webhook secret for the GitHub push trigger.
- **Real environments.** Separate dev, staging and prod hosts, with the prod stage doing the real imports instead of a dry run.
- **Contract tests in CI.** Validate MI responses against the OpenAPI schemas on every build.

## Demo recording

5-minute walkthrough: **link to be added**.

1. The architecture in one picture, and why the backends are self-built.
2. One `docker compose up`: the stack starts, publishes and verifies itself.
3. The Developer Portal: discover, subscribe, get a token, call each API.
4. Error handling: unknown account (404), database down (503), credit engine fault (422 / 502), timeout (504), all in one error format.
5. Throttling: the Loan tier returning 429 after 10 calls.
6. Jenkins: a green run, then a forced import failure rolling back to the previous release.