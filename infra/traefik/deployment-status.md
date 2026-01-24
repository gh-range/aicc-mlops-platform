## Middleware Configuration

\`\`\`
NAME               AGE
dashboard-auth     6m22s
rate-limit         5m38s
security-headers   5m45s
\`\`\`

## IngressRoute Status

\`\`\`
NAME                AGE
traefik-dashboard   16m
\`\`\`

## Recent Logs (Last 20 lines)

\`\`\`
{"level":"warn","time":"2026-01-23T06:37:37Z","message":"Traefik can reject some encoded characters in the request path.When your backend is not fully compliant with [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986),it is recommended to set these options to `false` to avoid split-view situation.Refer to the documentation for more details: https://doc.traefik.io/traefik/v3.6/migrate/v3/#encoded-characters-configuration-default-values"}
{"level":"info","version":"3.6.7","time":"2026-01-23T06:37:37Z","message":"Traefik version 3.6.7 built on 2026-01-14T14:04:03Z"}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"Version check is enabled."}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"Traefik checks for new releases to notify you if your version is out of date."}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"It also collects usage data during this process."}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"Check the documentation to get more info: https://doc.traefik.io/traefik/contributing/data-collection/"}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"\nStats collection is disabled.\nHelp us improve Traefik by turning this feature on :)\nMore details on: https://doc.traefik.io/traefik/contributing/data-collection/\n"}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"Starting provider aggregator *aggregator.ProviderAggregator"}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"Starting provider *traefik.Provider"}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"Starting provider *ingress.Provider"}
{"level":"info","providerName":"kubernetes","time":"2026-01-23T06:37:37Z","message":"ingress label selector is: \"\""}
{"level":"info","providerName":"kubernetes","time":"2026-01-23T06:37:37Z","message":"Creating in-cluster Provider client"}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"Starting provider *crd.Provider"}
{"level":"info","providerName":"kubernetescrd","time":"2026-01-23T06:37:37Z","message":"label selector is: \"\""}
{"level":"info","providerName":"kubernetescrd","time":"2026-01-23T06:37:37Z","message":"Creating in-cluster Provider client"}
{"level":"info","time":"2026-01-23T06:37:37Z","message":"Starting provider *acme.ChallengeTLSALPN"}
\`\`\`
