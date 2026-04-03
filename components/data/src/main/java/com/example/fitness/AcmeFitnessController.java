package com.example.fitness;

import com.example.model.Customer;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController(value = "/acme")
public class AcmeFitnessController {
  private final CustomerService customerService;

  public AcmeFitnessController(CustomerService customerService) {
    this.customerService = customerService;
  }

  /**
   * Fake login used by the clients to simulate a user login
   *
   * @param email
   * @return
   */
  @PostMapping("/login")
  public Customer login(String email) {
    Optional<Customer> customer = customerService.findCustomerByEmail(email);

    if (customer.isEmpty()) {
      throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
    }

    return customer.get();
  }
}
