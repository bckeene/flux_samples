import "influxdata/influxdb/secrets"
import "experimental/usage"
import "math"
import "http"
import "json"

option task = {name: "Hourly cost alert", every: 1h, offset: 1m}

//SendGrid API key
sendGridAPIKey = secrets.get(key: "SENDGRID_APIKEY")

//To and From email addresses
toEmail = "..."
fromEmail = "..."

//Hourly cost limit
hourlyCostLimit = 50.0

//Organization rates
dataInUnitRate = 0.002
queryUnitRate = 0.01
storageUnitRate = 0.002

//Start time
startTime = -1h

//dataInCost
dataInCost =
    usage.from(start: startTime, stop: now())
        |> filter(
            fn: (r) =>
                r._measurement == "http_request" and r.status == "204" and r._field == "req_bytes",
        )
        |> sum()
        |> map(fn: (r) => ({r with _value: float(v: r._value) / 1000000.0 * dataInUnitRate}))

//queryCountCost
queryCountCost =
    usage.from(start: startTime, stop: now())
        |> filter(
            fn: (r) =>
                r._measurement == "query_count" and r.status == "200" and (r.endpoint
                        ==
                        "/api/v2/query" or r.endpoint == "/query"),
        )
        |> sum()
        |> map(fn: (r) => ({r with _value: float(v: r._value) / 100.0 * queryUnitRate}))

//storageCost
storageCost =
    usage.from(start: startTime, stop: now())
        |> range(start: startTime, stop: now())
        |> filter(fn: (r) => r._measurement == "storage_usage_bucket_bytes" and r._field == "gauge")
        |> group()
        |> aggregateWindow(every: 1h, fn: sum)
        |> sum()
        |> map(fn: (r) => ({r with _value: float(v: r._value) / 1000000000.0 * storageUnitRate}))

//totalCost
totalCost =
    union(tables: [dataInCost, queryCountCost, storageCost])
        |> group()
        |> sum(column: "_value")

//Trigger SendGrid API call if totalCost exceeds hourlyCostLimit
totalCost
    |> map(
        fn:
            (r) =>
                if r._value > hourlyCostLimit then
                    {r with _value:
                            http.post(
                                url: "https://api.sendgrid.com/v3/mail/send",
                                headers: {
                                    "Content-Type": "application/json",
                                    "Authorization": "Bearer ${sendGridAPIKey}",
                                },
                                data:
                                    json.encode(
                                        v:
                                            {
                                                "personalizations": [
                                                    {"to": [{"email": "${toEmail}"}]},
                                                ],
                                                "from": {"email": "${fromEmail}"},
                                                "subject": "InfluxDB hourly spend alert",
                                                "content":
                                                    [
                                                        {
                                                            "type": "text/plain",
                                                            "value":
                                                                "Hourly Cost Exceeded - your account has generated $"
                                                                    +
                                                                    string(v: r._value)
                                                                    +
                                                                    " in total spend over the past hour.",
                                                        },
                                                    ],
                                            },
                                    ),
                            ),
                    }
                else
                    {r with _value: 0},
    )
