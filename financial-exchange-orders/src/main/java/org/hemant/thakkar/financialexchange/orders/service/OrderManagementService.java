package org.hemant.thakkar.financialexchange.orders.service;

import java.util.List;

import org.hemant.thakkar.financialexchange.orders.domain.ExchangeException;
import org.hemant.thakkar.financialexchange.orders.domain.OrderActivityEntry;
import org.hemant.thakkar.financialexchange.orders.domain.OrderEntry;
import org.hemant.thakkar.financialexchange.orders.domain.OrderReport;

public interface OrderManagementService {
	long acceptNewOrder(OrderEntry orderEntry) throws ExchangeException;
	void cancelOrder(long orderId) throws ExchangeException;
	OrderReport getOrderStatus(long orderId) throws ExchangeException;
	void updateOrder(long orderId, OrderEntry orderEntry) throws ExchangeException;
	List<OrderReport> getOrdersForProduct(long productId) throws ExchangeException;
	void addOrderActivity(long orderId, OrderActivityEntry orderTradeEntry) throws ExchangeException;
}

