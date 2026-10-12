package ke.co.daqiqtech.jamii.mocks.credit;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;
import org.springframework.ws.wsdl.wsdl11.DefaultWsdl11Definition;
import org.springframework.xml.xsd.SimpleXsdSchema;
import org.springframework.xml.xsd.XsdSchema;

/** Publishes the WSDL at /ws/creditCheck.wsdl (servlet path set in application.yml). */
@Configuration
public class WebServiceConfig {

    @Bean(name = "creditCheck")
    public DefaultWsdl11Definition creditCheckWsdl(XsdSchema creditCheckSchema) {
        DefaultWsdl11Definition definition = new DefaultWsdl11Definition();
        definition.setPortTypeName("CreditCheckPort");
        definition.setLocationUri("/ws");
        definition.setTargetNamespace(CreditCheckEndpoint.NAMESPACE);
        definition.setSchema(creditCheckSchema);
        return definition;
    }

    @Bean
    public XsdSchema creditCheckSchema() {
        return new SimpleXsdSchema(new ClassPathResource("xsd/credit-check.xsd"));
    }
}
