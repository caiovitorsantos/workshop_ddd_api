# syntax=docker/dockerfile:1
# check=error=true

# Image for the workshop API. Multi-stage, with two targets:
#
#   production (default) -- slim image, non-root user, no development gems.
#                           This is what `docker build .` produces.
#   development          -- includes rspec/rubocop/brakeman and runs the Rails
#                           server; this is the target docker-compose.yml uses.
#
#   docker build -t oficina-api .                          # production
#   docker build --target development -t oficina-api:dev . # development
#
# The full environment (API + PostgreSQL) comes up with `docker compose up`.

ARG RUBY_VERSION=3.3.8

# --- Shared base -------------------------------------------------------------
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libpq5 postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# --- Toolchain for native gems (pg, bcrypt, bootsnap) ------------------------
FROM base AS toolchain

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# --- Development target ------------------------------------------------------
FROM toolchain AS development

ENV RAILS_ENV="development"

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]

# --- Production build (discarded from the final image) -----------------------
FROM toolchain AS build

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development"

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# --- Final production image --------------------------------------------------
FROM base

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development"

# Runs as an unprivileged user: an RCE in the app does not become root here.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
