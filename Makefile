include make_env

NS ?= mlan
VERSION ?= latest

IMAGE_NAME ?= openldap
CONTAINER_NAME ?= openldap
CONTAINER_INSTANCE ?= default
SHELL ?= /bin/sh

.PHONY: build build-force push shell exec run run-fg start stop rm-container rm-image purge redo release dump copy copya create again sleep case1 case2 test0 test1 test2 apply2

build: Dockerfile
	docker build -t $(NS)/$(IMAGE_NAME):$(VERSION) -f Dockerfile .

push:
	docker push $(NS)/$(IMAGE_NAME):$(VERSION)

shell:
	docker run --rm --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) -i -t $(PORTS) $(VOLUMES) $(ENV) $(NS)/$(IMAGE_NAME):$(VERSION) $(SHELL)

exec:
	docker exec -it $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) $(SHELL)

run-fg:
	docker run --rm --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) $(PORTS) $(VOLUMES) $(ENV) $(NS)/$(IMAGE_NAME):$(VERSION)

run:
	docker run -d --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) $(PORTS) $(VOLUMES) $(ENV) $(NS)/$(IMAGE_NAME):$(VERSION)

start:
	docker start $(CONTAINER_NAME)-$(CONTAINER_INSTANCE)

stop:
	docker stop $(CONTAINER_NAME)-$(CONTAINER_INSTANCE)

rm-container:
	docker rm $(CONTAINER_NAME)-$(CONTAINER_INSTANCE)

rm-image:
	docker image rm $(NS)/$(IMAGE_NAME)\:$(VERSION)

dump:
	sudo slapcat -n0 -o ldif-wrap=no -l seed/0/conf.ldif
	sudo slapcat -n1 -o ldif-wrap=no -l seed/1/data.ldif

create:
	docker create --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) $(PORTS) $(VOLUMES) $(ENV) $(NS)/$(IMAGE_NAME)\:$(VERSION)

createa:
	docker create --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) $(PORTS) $(VOLUMES) $(ENV) $(DOMAIN) $(NS)/$(IMAGE_NAME)\:$(VERSION)

copy:
	docker cp seed $(CONTAINER_NAME)-$(CONTAINER_INSTANCE):/var/lib/openldap/

copya:
	docker cp seed/a $(CONTAINER_NAME)-$(CONTAINER_INSTANCE):/var/lib/openldap/seed/

purge: rm-container rm-image

sleep:
	sleep 3

release: build
	make push -e VERSION=$(VERSION)

redo: stop purge build create start exec

again: stop purge build create copy start sleep test1

build-force: stop purge build

case1: dump create copy start sleep test0 test1

case2: createa copya start sleep test0 test1 test2

apply2:
	docker exec $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) ldap add -f ldif_intern /var/lib/openldap/seed/a/1-data.ldif

default: build

test0:
	ldapwhoami -H ldap://:400 -x
test1:
	ldapsearch -H ldap://:400 -xLLL -s base namingContexts
test2:
	ldapsearch -H ldap://:400 -xLLL -b dc=example,dc=com
test3:
	ldapsearch -H ldap://:400 -xLLL -s base "+"

