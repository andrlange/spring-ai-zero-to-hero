/*
 * Copyright 2025 - 2025 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.example;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import org.slf4j.Logger;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
public class WeatherTools {

  private static final Logger logger = org.slf4j.LoggerFactory.getLogger(WeatherTools.class);

  private static final String FORECAST_URL =
      "https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m";

  private static final String GEOCODING_URL =
      "https://geocoding-api.open-meteo.com/v1/search?name={name}&count=1";

  private final RestClient restClient;

  public WeatherTools() {
    this.restClient = RestClient.create();
  }

  public record TemperatureResult(
      String resolvedLocation,
      Double latitude,
      Double longitude,
      Double temperatureCelsius,
      String note) {}

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record GeocodingResponse(List<Result> results) {
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Result(String name, String country, Double latitude, Double longitude) {}
  }

  @JsonIgnoreProperties(ignoreUnknown = true)
  public record WeatherResponse(@JsonProperty("current") Current current) {
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Current(@JsonProperty("temperature_2m") Double temperature) {}
  }

  @Tool(
      description =
          "Get the current temperature (in celsius) for a location. Provide EITHER"
              + " latitude+longitude OR a city name. When a city is given without coordinates the"
              + " tool geocodes it first.")
  public TemperatureResult getTemperature(
      @ToolParam(required = false, description = "Latitude (optional if city is provided)")
          Double latitude,
      @ToolParam(required = false, description = "Longitude (optional if city is provided)")
          Double longitude,
      @ToolParam(required = false, description = "City name (optional if coordinates are provided)")
          String city) {

    String resolvedLocation = city;
    Double lat = latitude;
    Double lon = longitude;

    // Resolve city → coordinates if coords not fully provided
    if ((lat == null || lon == null) && city != null && !city.isBlank()) {
      GeocodingResponse geo =
          restClient.get().uri(GEOCODING_URL, city).retrieve().body(GeocodingResponse.class);
      if (geo != null && geo.results() != null && !geo.results().isEmpty()) {
        GeocodingResponse.Result first = geo.results().get(0);
        lat = first.latitude();
        lon = first.longitude();
        resolvedLocation = first.name() + (first.country() != null ? ", " + first.country() : "");
        logger.info("Geocoded '{}' -> {} ({}, {})", city, resolvedLocation, lat, lon);
      } else {
        return new TemperatureResult(
            city,
            null,
            null,
            null,
            "City not found: '" + city + "'. Try providing latitude and longitude.");
      }
    }

    if (lat == null || lon == null) {
      return new TemperatureResult(
          null, null, null, null, "Please provide either latitude+longitude or a city name.");
    }

    WeatherResponse response =
        restClient.get().uri(FORECAST_URL, lat, lon).retrieve().body(WeatherResponse.class);
    Double temp =
        response != null && response.current() != null ? response.current().temperature() : null;

    if (resolvedLocation == null || resolvedLocation.isBlank()) {
      resolvedLocation = String.format("(%.4f, %.4f)", lat, lon);
    }

    logger.info("Temperature for {} ({}, {}): {}°C", resolvedLocation, lat, lon, temp);

    return new TemperatureResult(resolvedLocation, lat, lon, temp, null);
  }
}
