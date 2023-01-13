build:
	mix escript.build

repl:
	iex -S mix

clean:
	-rm -r _build erl_crash.dump

docker-build:
	docker build -t distribuidos:dev .

grpc-proto-build:
	protoc --elixir_out=plugins=grpc:./lib/raft private/grpc/*.proto
