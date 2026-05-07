# Flux Samples

A collection of [Flux](https://docs.influxdata.com/flux/) query examples for InfluxDB. These samples demonstrate common patterns for querying, transforming, and alerting on time-series data.

## Files

| File | Description |
|------|-------------|
| `basics.flux` | Simple queries for retrieving weather data (wave height, air temp, swell, water temp) |
| `geo_wave_height.flux` | Geospatial query that shapes location data and finds max wave height |
| `hourlyCostAlert.flux` | Scheduled task that monitors InfluxDB usage costs and sends email alerts via SendGrid |

## Data Source

These samples query data from [Storm Glass](https://stormglass.io/), a weather and ocean data API, stored in an InfluxDB bucket called `stormglass`.
