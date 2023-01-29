.PHONY: deps

build:
	mix escript.build

deps:
	mix deps.get

repl:
	iex -S mix

install-tools:
	make asdf-plugins
	asdf install
	mix local.hex --force
	mix escript.install hex protobuf --force
	asdf reshim

asdf-plugins:
	@echo "Adding asdf plugins"
	-@awk '{print $$1}' .tool-versions | xargs -I{} asdf plugin add {}

clean:
	-rm -r _build erl_crash.dump

# Docker tasks
docker-build:
	docker build -t distribuidos:dev .

# GRCP tasks
grpc-proto-build:
	protoc --elixir_out=plugins=grpc:./lib/raft private/grpc/*.proto

grpc-proto-lint:
	protolint lint -fix private/grpc
