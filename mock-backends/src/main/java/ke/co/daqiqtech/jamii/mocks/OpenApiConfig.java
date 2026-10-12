package ke.co.daqiqtech.jamii.mocks;

import io.swagger.v3.oas.models.ExternalDocumentation;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** OpenAPI metadata for Swagger UI (/swagger-ui.html) and the spec (/v3/api-docs). */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI jamiiMockOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("Jamii Mock Backends")
                        .version("1.0.0")
                        .description("""
                                Mock backends for the Jamii Savings integration platform. All data is synthetic.

                                **Customer system (REST/JSON)**: documented below.

                                **Credit-check engine (SOAP 1.1)**: `POST /ws`, operation `CheckEligibility`.
                                Its contract is the WSDL at [/ws/creditCheck.wsdl](/ws/creditCheck.wsdl).
                                Rules: income 0 or customer 6000 return soap:Client; customer 5000 returns soap:Server;
                                customer 5004 answers after 12 s.

                                Every response carries `Server`, `X-Powered-By` and `X-Internal-*` headers,
                                which WSO2 MI must strip."""))
                .externalDocs(new ExternalDocumentation()
                        .description("Credit-check SOAP contract (WSDL)")
                        .url("/ws/creditCheck.wsdl"));
    }
}
