-include    *.mk

BLD_ARG  ?= --build-arg DIST=alpine --build-arg REL=3.12
BLD_REPO ?= mlan/openldap
BLD_VER  ?= latest
TST_ENV  ?= -C test
TST_TGTE ?= $(addprefix test-,all diff down env htop logs pull sh up)
TST_TGTI ?= test_% test-up_%

build: Dockerfile
	docker build $(BLD_ARG) --tag $(BLD_REPO):$(BLD_VER) .

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

ps:
	docker ps -a

prune:
	docker image prune

clean:
	docker images | grep $(BLD_REPO) | awk '{print $$1 ":" $$2}' | uniq | xargs docker rmi

$(TST_TGTE):
	${MAKE} $(TST_ENV) $@

$(TST_TGTI):
	${MAKE} $(TST_ENV) $@
