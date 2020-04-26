package org.hemant.thakkar.financialexchange.info.controller;

import org.hemant.thakkar.financialexchange.info.domain.APIResponse;
import org.hemant.thakkar.financialexchange.info.domain.ResultCode;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ApplicationPingController {

	@GetMapping(value = "/finex/api/info/status", produces = "application/json")
	public APIResponse sayHello() {
		APIResponse response = new APIResponse();
		response.setResponseCode(ResultCode.APPLICATION_ALIVE.getCode());
		response.setInfoMessage(ResultCode.APPLICATION_ALIVE.getMessage());
		response.setErrorMessage("");
		response.setWarningMessage("");
		response.setSuccess(true);
		return response;
	}
	
	@GetMapping(value = "/index.html", produces = "text/html")
	public String indexHtml() {
		return new String("<!doctype html>\n" + 
				"<html>\n" + 
				"  <head>\n" + 
				"    <title>Financial Exchange Information Service</title>\n" + 
				"  </head>\n" + 
				"  <body>\n" + 
				"    <p>Financial Exchange Product Information is alive</p>\n" + 
				"  </body>\n" + 
				"</html>");
	}

	@GetMapping(value = "/**", produces = "application/json", consumes = "application/json")
	public APIResponse unrecognizedAPIResponse()  {
		APIResponse response = new APIResponse();
		response.setResponseCode(ResultCode.INCORRECT_API.getCode());
		response.setErrorMessage(ResultCode.INCORRECT_API.getMessage());
		response.setInfoMessage("");
		response.setWarningMessage("");
		response.setSuccess(true);
		return response;
	}

} 
