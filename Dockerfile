FROM ghcr.io/gleam-lang/gleam:v1.18.1-erlang-alpine AS build

WORKDIR /app
COPY gleam.toml manifest.toml ./
COPY src ./src
RUN gleam export erlang-shipment

FROM docker.io/library/erlang:29.0.6.0-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends adduser ca-certificates \
    && update-ca-certificates \
    && addgroup --system app \
    && adduser --system --ingroup app app \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/build/erlang-shipment ./
USER app

EXPOSE 8000
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
CMD ["run"]
