package com.example.fitness;

import com.example.data.DataFiles;
import com.example.model.Product;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
public class ProductCatalog {

  private final List<Product> products;

  public ProductCatalog(DataFiles dataFiles) {
    this.products = Arrays.stream(dataFiles.getProducts()).toList();
  }

  public Optional<Product> findProductById(int id) {
    return this.products.stream().filter(p -> p.getId() == id).findFirst();
  }

  public List<Product> getAllProducts() {
    return this.products;
  }
}
