# Gift Shop API

Rails 8.1 JSON API backend for the gift shop's Angular storefront
(`gift-shop-angular`). The storefront currently runs on dummy data; this API
is being built step by step to replace it.

## Requirements

| Tool       | Version                                 |
|------------|-----------------------------------------|
| Ruby       | 3.3.6 (see `.ruby-version`)             |
| PostgreSQL | 14+                                     |
| libvips    | any recent (image variants for uploads) |

On macOS with Homebrew:

```bash
brew install postgresql@14 vips
brew services start postgresql@14
```

## Setup

1. Get `config/master.key` from the project owner and place it in `config/`.
   It decrypts `config/credentials.yml.enc` and is never committed to git.
2. Install gems, create the databases and start the server:

   ```bash
   bin/setup
   ```

   The API runs at <http://localhost:3000>. `GET /up` returns 200 when the app
   has booted. Use `bin/setup --skip-server` to set up without starting it,
   and `bin/dev` to start the server later.

### Databases

| Environment | Database(s)                                                                   |
|-------------|-------------------------------------------------------------------------------|
| development | `giftee_development`                                                          |
| test        | `giftee_test`                                                                 |
| production  | `giftee_production`, `giftee_production_cache`, `giftee_production_queue`     |

Production splits Solid Cache (`Rails.cache`) and Solid Queue (background jobs)
into their own databases. In development the cache is in memory and jobs run
in-process.

## Conventions

- **Time zone:** the app runs in `Kuwait` (Asia/Kuwait, UTC+3). Timestamps are
  stored in UTC and converted on read.
- **Secrets:** add them with `bin/rails credentials:edit`, never in code or
  committed `.env` files.

## Tests and checks

```bash
bin/rails test   # test suite
bin/ci           # everything CI runs: RuboCop, bundler-audit, Brakeman, tests, seeds
```

GitHub Actions runs the same checks on every push to `main` and on pull
requests, against a PostgreSQL service container.

## Deployment

The app ships as a Docker image deployed with [Kamal](https://kamal-deploy.org)
(`config/deploy.yml`). The deployment config still has placeholders and no
production PostgreSQL server yet, so it is not ready to deploy.
