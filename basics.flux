// Basic Flux Queries for Storm Glass Weather Data
// Each query below retrieves a specific field from the "stormglass" bucket.

// Wave height — uses dashboard time range and converts meters to feet
from(bucket: "stormglass")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "weather")
  |> filter(fn: (r) => r["_field"] == "wave_height")
  |> map(fn: (r) => ({ r with _value: r._value * 3.28084 }))  // meters → feet

// Air temperature (Celsius) over the last 5 days
from(bucket: "stormglass")
  |> range(start: -5d, stop: now())
  |> filter(fn: (r) => r["_measurement"] == "weather")
  |> filter(fn: (r) => r["_field"] == "air_temp")

// Swell height over the last 5 days
from(bucket: "stormglass")
  |> range(start: -5d, stop: now())
  |> filter(fn: (r) => r["_measurement"] == "weather")
  |> filter(fn: (r) => r["_field"] == "swell_height")

// Water temperature (Celsius) over the last 5 days
from(bucket: "stormglass")
  |> range(start: -5d, stop: now())
  |> filter(fn: (r) => r["_measurement"] == "weather")
  |> filter(fn: (r) => r["_field"] == "water_temp")
