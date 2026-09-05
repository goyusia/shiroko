FROM erlang:27.1.1.0-alpine AS build

COPY --from=ghcr.io/gleam-lang/gleam:v1.18.1-erlang-alpine /bin/gleam /bin/gleam

WORKDIR /app
COPY gleam.toml manifest.toml ./
COPY src ./src
RUN gleam export erlang-shipment

FROM erlang:27.1.1.0-alpine

RUN addgroup --system app && adduser --system app -G app

WORKDIR /app
COPY --from=build /app/build/erlang-shipment ./
USER app

EXPOSE 8000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
