FROM elixir:1.14 as build

WORKDIR /app
COPY ./mix.* ./

RUN mix local.hex --force &&\
    mix local.rebar --force &&\
    mix deps.get

COPY . .

RUN make build &&\
    make clean

FROM elixir:1.14

WORKDIR /app
RUN apt update &&\
    # Agregar handler para sigterm a server
    apt install -y tini

COPY --from=build /app/distribuidos /app/distribuidos

ENTRYPOINT [ "tini", "/app/distribuidos" ]
