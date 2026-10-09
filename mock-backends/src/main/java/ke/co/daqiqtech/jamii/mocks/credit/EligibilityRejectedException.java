package ke.co.daqiqtech.jamii.mocks.credit;

import org.springframework.ws.soap.server.endpoint.annotation.FaultCode;
import org.springframework.ws.soap.server.endpoint.annotation.SoapFault;

/** Business rejection: returned as soap:Client. MI maps this to 422 ELIGIBILITY_REJECTED. */
@SoapFault(faultCode = FaultCode.CLIENT)
public class EligibilityRejectedException extends RuntimeException {
    public EligibilityRejectedException(String message) {
        super(message);
    }
}
