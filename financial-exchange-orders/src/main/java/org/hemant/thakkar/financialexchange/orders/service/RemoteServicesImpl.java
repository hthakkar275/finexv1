package org.hemant.thakkar.financialexchange.orders.service;

import java.util.ArrayList;
import java.util.List;

import org.hemant.thakkar.financialexchange.orders.domain.APIResponse;
import org.hemant.thakkar.financialexchange.orders.domain.Order;
import org.hemant.thakkar.financialexchange.orders.domain.OrderBookEntry;
import org.hemant.thakkar.financialexchange.orders.domain.ResultCode;
import org.hemant.thakkar.financialexchange.orders.monitor.ExecPosRecorder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service("remoteServicesImpl")
public class RemoteServicesImpl implements RemoteServices {

	private static final Logger logger = LoggerFactory.getLogger(RemoteServicesImpl.class);
	private static final String className = RemoteServicesImpl.class.getSimpleName();
		
	@Autowired
	@Qualifier("restTemplate")
	private RestTemplate restTemplate;

	@Autowired
	@Qualifier("asyncExecPosRecorder")
	private ExecPosRecorder execPosRecorder;
	
	@Value("${remote.services.baseurl:http://localhost}")
	private String remoteServicesBaseurl;
	
	@Value("${remote.services.useNonStandardPort:true}")
	private boolean remoteServicesUseNonStandardPort;
	
	@Value("${product.service.port:8080}")
	private int productServicePort;

	@Value("${participant.service.port:8081}")
	private int participantServicePort;

	@Value("${order.service.port:8082}")
	private int orderServicePort;

	@Value("${orderbook.service.port:8083}")
	private int orderbookServicePort;

	@Value("${trade.service.port:8084}")
	private int tradeServicePort;

	@Value("${spring.datasource.url")
	private String springDatasourceUrl;

	@Override
	public boolean isValidProduct(long productId) {
		execPosRecorder.recordExecutionPoint(className, "isValidProduct", productId, "entry");
		boolean validProduct = false;
		try {
			StringBuffer stringBuffer = new StringBuffer(remoteServicesBaseurl);
			if (remoteServicesUseNonStandardPort) {
				stringBuffer.append(":").append(productServicePort);
			}
			stringBuffer.append("/finex/internal/api/product/equity/");
			stringBuffer.append(productId);
			String serviceUrl = stringBuffer.toString(); 
			System.out.println("The isValidProduct service url: " + serviceUrl);
			
			HttpHeaders headers = new HttpHeaders();
			headers.setContentType(MediaType.APPLICATION_JSON);
			HttpEntity<String> entity = new HttpEntity<String>(headers);
			ResponseEntity<String> response = restTemplate.exchange(serviceUrl, HttpMethod.GET, entity, String.class);
			ObjectMapper mapper = new ObjectMapper();
			JsonNode root = mapper.readTree(response.getBody());
			int responseCode = root.get("responseCode").asInt();
			validProduct = responseCode == ResultCode.PRODUCT_FOUND.getCode();
		} catch (Exception e) {
			logger.error("Error while validating product", e);
		}
		execPosRecorder.recordExecutionPoint(className, "isValidProduct", productId, "exit");
		return validProduct;
	}

	@Override
	public boolean isValidParticipant(long participantId) {
		execPosRecorder.recordExecutionPoint(className, "isValidParticipant", participantId, "entry");
		boolean validParticipant = false;
		try {
			StringBuffer stringBuffer = new StringBuffer(remoteServicesBaseurl);
			if (remoteServicesUseNonStandardPort) {
				stringBuffer.append(":").append(participantServicePort);
			}
			stringBuffer.append("/finex/internal/api/participant/broker/");
			stringBuffer.append(participantId);
			String serviceUrl = stringBuffer.toString();
			System.out.println("isValidParticipant service url: " + serviceUrl);

			HttpHeaders headers = new HttpHeaders();
			headers.setContentType(MediaType.APPLICATION_JSON);
			HttpEntity<String> entity = new HttpEntity<String>(headers);
			ResponseEntity<String> response = restTemplate.exchange(serviceUrl, HttpMethod.GET, entity, String.class);
			ObjectMapper mapper = new ObjectMapper();
			JsonNode root = mapper.readTree(response.getBody());
			int responseCode = root.get("responseCode").asInt();
			validParticipant = responseCode == ResultCode.PARTICIPANT_FOUND.getCode();
		} catch (Exception e) {
			logger.error("Error while validating participant", e);
		}
		execPosRecorder.recordExecutionPoint(className, "isValidParticipant", participantId, "exit");
		return validParticipant;
	}

	@Override
	public boolean cancelOrderInBook(long orderId) {
		// TODO Auto-generated method stub
		return true;
	}

	@Override
	public boolean addOrderInBook(Order order) {
		execPosRecorder.recordExecutionPoint(className, "addOrderInBook", order.getId(), "entry");
		logger.trace("Entering addOrderInBook: " + order);
		boolean addedToBook = false;
		try {
			StringBuffer stringBuffer = new StringBuffer(remoteServicesBaseurl);
			if (remoteServicesUseNonStandardPort) {
				stringBuffer.append(":").append(orderbookServicePort);
			}
			stringBuffer.append("/finex/internal/api/orderBook/order/");
			String serviceUrl = stringBuffer.toString();
			System.out.println("addOrderInBook service url: " + serviceUrl);

			OrderBookEntry orderBookEntry = new OrderBookEntry();
			orderBookEntry.setEntryTime(order.getEntryTime());
			orderBookEntry.setOrderId(order.getId());
			orderBookEntry.setPrice(order.getPrice());
			orderBookEntry.setProductId(order.getProductId());
			orderBookEntry.setQuantity(order.getQuantity());
			orderBookEntry.setSide(order.getSide());
			orderBookEntry.setType(order.getType());
			
			HttpHeaders headers = new HttpHeaders();
			headers.setContentType(MediaType.APPLICATION_JSON);
			HttpEntity<OrderBookEntry> entity = new HttpEntity<OrderBookEntry>(orderBookEntry, headers);
			
			ResponseEntity<APIResponse> response = restTemplate.exchange(serviceUrl, HttpMethod.POST, entity, APIResponse.class);
			addedToBook = response.getBody().getResponseCode() == ResultCode.ORDER_ACCEPTED.getCode();
		} catch (Exception e) {
			logger.error("Error during service call to orderbook service for order: " + order);
		}
		logger.trace("Exiting addOrderInBook: " + order);
		execPosRecorder.recordExecutionPoint(className, "addOrderInBook", order.getId(), "exit");
		return addedToBook;
	}

	@Override
	public List<Long> getTradesForOrder(long orderId) {
		// TODO Auto-generated method stub
		return new ArrayList<Long>();
	}

}
