# Distribuidos

## Dependencias

* [`protobuf-compiler`](https://grpc.io/docs/protoc-installation)

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

```
make repl
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
