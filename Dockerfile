FROM elixir:1.14-alpine as build

WORKDIR /app
COPY ./mix.* ./

RUN apk add make git &&\
    mix local.hex --force &&\
    mix local.rebar --force &&\
    mix deps.get &&\
    mix deps.compile

COPY . .

RUN make build &&\
    make clean

FROM erlang:25.2-alpine

WORKDIR /app
EXPOSE 50051/tcp
RUN apk add tini
    # Agregar handler para sigterm a server

COPY --from=build /app/distribuidos /app/distribuidos


ENTRYPOINT [ "tini", "/app/distribuidos" ]
