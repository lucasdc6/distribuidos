.PHONY: tools deps

export PATH := tools:$(PATH)

build:
	mix escript.build

deps:
	mix deps.get

repl:
	iex -S mix

clean:
	-rm -r _build erl_crash.dump

# Tools
tools: tools-dir tools-grpcurl tools-protolint

tools-dir:
	@mkdir -p tools

tools-clean:
	@rm -r tools

tools-grpcurl:
	@if ! which grpcurl > /dev/null; then \
		echo -n "Downloading grpcurl....."; \
		curl -sL https://github.com/fullstorydev/grpcurl/releases/download/v1.8.7/grpcurl_1.8.7_linux_x86_64.tar.gz -o tools/grpcurl.tar.gz; \
		tar xzf tools/grpcurl.tar.gz -C tools; \
		rm tools/grpcurl.tar.gz tools/LICENSE; \
		echo "\033[0;32mOK\033[0m"; \
	else \
		echo "grpcurl alredy exists"; \
	fi

tools-protolint:
	@if ! which protolint > /dev/null; then \
		echo -n "Downloading protolint..."; \
		curl -sL https://github.com/yoheimuta/protolint/releases/download/v0.42.2/protolint_0.42.2_Linux_x86_64.tar.gz -o tools/protolint.tar.gz; \
		tar xzf tools/protolint.tar.gz -C tools; \
		rm tools/protolint.tar.gz tools/LICENSE tools/README.md; \
		echo "\033[0;32mOK\033[0m"; \
	else \
		echo "protolint alredy exists"; \
	fi

# Docker tasks
docker-build:
	docker build -t distribuidos:dev .

# GRCP tasks
grpc-proto-build:
	protoc --elixir_out=plugins=grpc:./lib/raft private/grpc/*.proto

grpc-proto-lint:
	protolint lint -fix private/grpc
