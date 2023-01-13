build:
	mix escript.build

clean:
	-rm -r _build erl_crash.dump

docker-build:
	docker build -t distribuidos:dev .
