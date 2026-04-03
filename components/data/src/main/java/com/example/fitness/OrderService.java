package com.example.fitness;

import com.example.data.DataFiles;
import com.example.model.Order;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
public class OrderService {

  private List<Order> orders;

  public OrderService(DataFiles dataFiles) {
    this.orders = Arrays.asList(dataFiles.getOrders());
  }

  public Optional<Order> findOrderById(int id) {
    return this.orders.stream().filter(o -> o.getId() == id).findFirst();
  }

  public boolean isOrderReturnable(String id) {
    Order order = findOrderById(Integer.parseInt(id)).orElseThrow();
    return LocalDateTime.now().isBefore(order.getReturnEligibleUntil());
  }

  public List<Order> getOrdersByCustomerId(int customerId) {
    return orders.stream().filter(o -> o.getCustomerId() == customerId).toList();
  }
}
