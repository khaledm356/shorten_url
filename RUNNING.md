# Running Shortlink

## Prerequisites

- Ruby 2.6.10
- Bundler 2.4.x

## Install dependencies

```bash
cd shortlink
bundle install
```

## Database setup

```bash
bundle exec rails db:create db:migrate
```

## Run the server

```bash
bundle exec rails server
```

Optional: set a base URL for generated short URLs

```bash
BASE_URL=https://short.test bundle exec rails server
```

## Run tests

```bash
bundle exec rspec
```
