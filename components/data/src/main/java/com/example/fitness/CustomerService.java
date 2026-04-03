package com.example.fitness;

import com.example.data.DataFiles;
import com.example.model.Customer;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
public class CustomerService {

  private List<Customer> customers;

  public CustomerService(DataFiles dataFiles) {
    this.customers = Arrays.asList(dataFiles.getCustomers());
  }

  public Customer findCustomerById(int id) {
    return customers.stream().filter(c -> c.getId() == id).findFirst().orElseThrow();
  }

  public Optional<Customer> findCustomerByEmail(String email) {
    return customers.stream().filter(c -> c.getEmail().equals(email)).findFirst();
  }

  public List<Customer> getCustomers() {
    return customers;
  }
}
