import "influxdata/influxdb/secrets"
import "experimental/usage"
import "http"
import "json"

// Task config
option task = {name: "Hourly cost alert", every: 1h, offset: 1m}

// Secrets and config
sendGridAPIKey = secrets.get(key: "SENDGRID_APIKEY")
toEmail = "..."
fromEmail = "..."
hourlyCostLimit = 50.0

// Pricing rates
dataInUnitRate = 0.002
queryUnitRate = 0.01
storageUnitRate = 0.002

// Time range
startTime = -1h
baseUsage = usage.from(start: startTime, stop: now())

// Cost calculations
dataInCost =
    baseUsage
        |> filter(fn: (r) => r._measurement == "http_request" and r.status == "204" and r._field == "req_bytes")
        |> sum()
        |> map(fn: (r) => ({r with _value: float(v: r._value) / 1000000.0 * dataInUnitRate}))

queryCountCost =
    baseUsage
        |> filter(fn: (r) => r._measurement == "query_count" and r.status == "200" and (r.endpoint == "/api/v2/query" or r.endpoint == "/query"))
        |> sum()
        |> map(fn: (r) => ({r with _value: float(v: r._value) / 100.0 * queryUnitRate}))

storageCost =
    baseUsage
        |> filter(fn: (r) => r._measurement == "storage_usage_bucket_bytes" and r._field == "gauge")
        |> aggregateWindow(every: 1h, fn: sum)
        |> sum()
        |> map(fn: (r) => ({r with _value: float(v: r._value) / 1000000000.0 * storageUnitRate}))

// Calculate total cost
totalCost =
    union(tables: [dataInCost, queryCountCost, storageCost])
        |> reduce(identity: {_value: 0.0}, fn: (r, acc) => ({_value: acc._value + r._value}))

// Email payload function
buildEmailPayload = (cost) => json.encode(
    v: {
        "personalizations": [{"to": [{"email": toEmail}]}],
        "from": {"email": fromEmail},
        "subject": "InfluxDB hourly spend alert",
        "content": [{
            "type": "text/plain",
            "value": "Hourly Cost Exceeded - your account has generated $" + string(v: cost) + " in total spend over the past hour."
        }]
    }
)

// Trigger alert
totalCost
    |> map(fn: (r) =>
        if r._value > hourlyCostLimit then
            {r with _value: http.post(
                url: "https://api.sendgrid.com/v3/mail/send",
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer ${sendGridAPIKey}",
                },
                data: buildEmailPayload(cost: r._value)
            )}
        else
            {r with _value: 0.0}
    )
