# Shortlink (Rails API)

Shortlink is a Rails API-only URL shortener with deterministic (idempotent) encoding.

## Endpoints

- POST /encode
  - Request: { "original_url": "https://example.com" }
  - Response: { "original_url": "...", "code": "AbC12", "short_url": "https://host/AbC12" }
- POST /decode
  - Request: { "code": "AbC12" } OR { "short_url": "https://host/AbC12" }
  - Response: { "original_url": "https://example.com" }
- GET /:code (optional)
  - 302 redirect to the original URL

`short_url` is built from `ENV["BASE_URL"]` when present, otherwise from the request base URL.

## Security notes (attack vectors and mitigations)

- Phishing/malware abuse: short URLs can hide destination. Mitigate with user reporting, abuse monitoring, and allow/deny lists.
- SSRF (future preview/fetch features): if a URL fetcher is added later, enforce network egress rules and block internal IP ranges.
- Code enumeration/scraping: base62 codes are sequential; rate-limit (Rack::Attack), add IP throttles, and monitor unusual traffic.
- Request size limits/DoS: enforce max body size at the reverse proxy and Rails middleware level.
- Open redirects: redirects are intended behavior; document abuse prevention and enforce validation rules.
- Injection (SQL/log): use strong params, ActiveRecord, and filter sensitive params (original_url, short_url).
- Scheme validation: only allow http/https to block javascript:, data:, file: URLs.

## Scalability and collision approach

- This implementation uses base62(id). IDs are unique, so codes are collision-free in this setup.
- If random codes were used instead: enforce unique index on `code`, retry on conflict, and monitor collision rates.
- For scale: move to Postgres, add Redis caching for hot lookups, and consider read replicas.
- For sharding: use global ID allocation (Snowflake/ULID) and shard-aware routing.

## Data model

- ShortUrl
  - original_url: string(2048), unique, indexed
  - code: string(32), unique, indexed

## Tests

RSpec request specs cover encode/decode behavior, idempotency, and redirects.
