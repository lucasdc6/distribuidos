.PHONY: tools deps
build:
	mix escript.build

deps:
	mix deps.get

tools:
	mkdir -p tools
	curl -sL https://github.com/fullstorydev/grpcurl/releases/download/v1.8.7/grpcurl_1.8.7_linux_x86_64.tar.gz -o tools/grpcurl.tar.gz
	tar xzf tools/grpcurl.tar.gz -C tools
	rm tools/grpcurl.tar.gz tools/LICENSE

repl:
	iex -S mix

clean:
	-rm -r _build erl_crash.dump

docker-build:
	docker build -t distribuidos:dev .

grpc-proto-build:
	protoc --elixir_out=plugins=grpc:./lib/raft private/grpc/*.proto
