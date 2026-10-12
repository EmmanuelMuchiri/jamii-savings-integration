# MI project

Multi-module Maven project created with the WSO2 MI VS Code extension (Jira S3.1):

| Module | Contents |
| --- | --- |
| `common/` | Common_InSeq, Common_MaskedLog, Common_ErrorResponse, Common_FaultSeq, Common_HeaderHygiene, MaskingMediator |
| `balance-api/` | BalanceAPI, AccountsDataService, JamiiAccountsDS |
| `customer-api/` | CustomerAPI, CustomerBackendEP |
| `loan-api/` | LoanEligibilityAPI, DNE SOAP endpoint, loan-request.schema.json |
| `composite/` | CAR packaging |

Each API module carries its MI unit test suites under `src/test/`.
