# Distribuidos

## Dependencias

### Base

Las siguientes son las dependencias del sistema necesarias para tener
funcionando `asdf` e instalar las herramientas

* `git`
* `curl`
* `make`
* `unzip`
* `gcc`
* `g++`
* `libssl-dev`
* `automake`
* `autoconf`
* `libncurses5-dev`

#### Debian

```bash
sudo apt update
sudo apt install -y git curl make unzip g++ libssl-dev automake autoconf libncurses5-dev
```

### ASDF

```
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.1
# Se recomienda agregar la siguiente línea a tu `bashrc`, `zshrc`, etc
. ~/.asdf/asdf.sh
```

#### Herramientas

Las siguientes son las herramientas usadas para el desarrollo del proyecto,
todas son gestionadas mediante `asdf`.

* `elixir`: 1.14.2-otp-25
* `erlang`: 25.2
* `grpcurl`: 1.8.7
* `protolint`: 0.42.2
* `protoc`: 3.20.3

Para poner en funcionamiento, seguir los siguientes pasos:

```bash
make asdf-plugins
asdf install
mix local.hex --force
mix escript.install hex protobuf --force
asdf reshim
```

## GRPC

### Agregar métodos GRPC

1. Modificar el archivo `private/grpc/server.proto`
2. Compilar el archivo ejecutando `make grpc-proto-build`

### Interactuar usando grpcurl

**Opcionalmente se puede bajar la herramienta localmente usando `make tools`**

```bash
# Listar servicios
./tools/grpcurl -plaintext -proto private/grpc/server.proto localhost:50051 list

# Listar métodos del servicio Raft.Server.GRPC
./tools/grpcurl -plaintext -proto private/grpc/server.proto localhost:50051 list Raft.Server.GRPC

# Describir un método para conocer su firma
./tools/grpcurl -plaintext -proto private/grpc/server.proto localhost:50051 describe Raft.Server.GRPC.RequestVote

# Describir un mensaje para conocer sus parámetros
./tools/grpcurl -plaintext -proto private/grpc/server.proto localhost:50051 describe .Raft.Server.RequestVoteParams

# Ejecutar un método
./tools/grpcurl -plaintext -d '{"current_term": 1}' -proto private/grpc/server.proto localhost:50051 Raft.Server.GRPC.RequestVote
```

### Interactuar usando el módulo Raft.Client

```elixir
$ make repl
iex(1)> Raft.Client.vote
{:ok,
 %Raft.Server.RequestVoteReply{
   server_id: 12294,
   vote: false,
   __unknown_fields__: []
 }}
iex(2)> Raft.Client.vote(15)
{:ok,
 %Raft.Server.RequestVoteReply{
   server_id: 12294,
   vote: true,
   __unknown_fields__: []
 }}
```
