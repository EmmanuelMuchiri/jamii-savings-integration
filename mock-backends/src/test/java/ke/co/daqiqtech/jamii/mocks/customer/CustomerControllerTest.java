package ke.co.daqiqtech.jamii.mocks.customer;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(CustomerController.class)
@Import(CustomerRepository.class)
@TestPropertySource(properties = "mocks.customer.slow-delay-ms=0")
class CustomerControllerTest {

    @Autowired
    private MockMvc mvc;

    @Test
    void returnsKnownCustomer() throws Exception {
        mvc.perform(get("/customers/1001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.customerId").value("1001"))
                .andExpect(jsonPath("$.nationalId").value("28456123"))
                .andExpect(header().exists("X-Internal-Trace"));
    }

    @Test
    void returns404ForUnknownCustomer() throws Exception {
        mvc.perform(get("/customers/9999")).andExpect(status().isNotFound());
    }

    @Test
    void returns500ForServerErrorRule() throws Exception {
        mvc.perform(get("/customers/5000")).andExpect(status().isInternalServerError());
    }

    @Test
    void slowRuleStillAnswers() throws Exception {
        mvc.perform(get("/customers/5004"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.customerId").value("5004"));
    }
}
