package ke.co.daqiqtech.jamii.mocks.credit;

import org.springframework.ws.soap.server.endpoint.annotation.FaultCode;
import org.springframework.ws.soap.server.endpoint.annotation.SoapFault;

/** Technical failure: returned as soap:Server. MI maps this to 502 BAD_GATEWAY. */
@SoapFault(faultCode = FaultCode.SERVER)
public class CreditEngineException extends RuntimeException {
    public CreditEngineException(String message) {
        super(message);
    }
}
