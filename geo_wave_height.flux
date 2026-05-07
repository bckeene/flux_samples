// Geospatial Wave Height Query
// Retrieves wave height data with lat/lon coordinates, shapes it for geo
// visualization, and finds the maximum wave height (in feet) over the last 48 hours.

import "experimental/geo"

from(bucket: "stormglass")
  |> range(start: -48h)
  |> filter(fn: (r) =>
    r._measurement == "weather" and
    (r._field == "lat" or r._field == "lon" or r._field == "wave_height")
  )
  // Pivot lat, lon, and wave_height into columns for geo shaping
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  // Convert to S2 cell format for geo visualization (level 10 ≈ ~10km precision)
  |> geo.shapeData(latField: "lat", lonField: "lon", level: 10)
  |> filter(fn: (r) => exists r.wave_height)
  |> map(fn: (r) => ({ r with _value: r.wave_height * 3.28084 }))  // meters → feet
  |> max()
