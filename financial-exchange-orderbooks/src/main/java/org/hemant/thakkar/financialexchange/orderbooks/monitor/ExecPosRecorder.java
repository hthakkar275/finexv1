package org.hemant.thakkar.financialexchange.orderbooks.monitor;

public interface ExecPosRecorder {
	void recordExecutionPoint(String className, String methodSignature, long id, String entryExit);
}
