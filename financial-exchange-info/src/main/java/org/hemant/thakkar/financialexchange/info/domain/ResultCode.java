package org.hemant.thakkar.financialexchange.info.domain;

public enum ResultCode {

	APPLICATION_ALIVE(1001, "Application is alive"),
	INCORRECT_API(1002, "Incorrect API or unsupported API"),
	GENERAL_ERROR(999999, "General error. Contact Exchange");
	
	ResultCode(int code, String message) {
		this.code = code;
		this.message = message;
	}
	
	private String message;
	private int code;
	
	public int getCode() {
		return this.code;
	}
	
	public String getMessage() {
		return this.message;
	}
}

