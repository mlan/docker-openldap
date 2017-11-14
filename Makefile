include make_env

NS ?= mlan
VERSION ?= latest

IMAGE_NAME ?= openldap
CONTAINER_NAME ?= openldap
CONTAINER_INSTANCE ?= default
SHELL ?= /bin/sh

.PHONY: build build-force push shell exec run run-fg start stop rm-container rm-image purge release export copy create  sleep test0 test1 test2 test3 test4 test5 test6 test7 test8 test9

build: Dockerfile
	docker build -t $(NS)/$(IMAGE_NAME):$(VERSION) -f Dockerfile .

build-force: stop purge build

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
	docker image rm $(NS)/$(IMAGE_NAME):$(VERSION)

export:
	sudo slapcat -n0 -o ldif-wrap=no -l seed/0/config.ldif
	sudo slapcat -n1 -o ldif-wrap=no -l seed/1/users.ldif

create:
	docker create --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) $(PORTS) $(VOLUMES) $(ENV) $(NS)/$(IMAGE_NAME):$(VERSION)

copy:
	docker cp seed $(CONTAINER_NAME)-$(CONTAINER_INSTANCE):/var/lib/openldap/

purge: rm-container rm-image

sleep:
	sleep 3

release: build
	make push -e VERSION=$(VERSION)

default: build

test0:
	ldapwhoami -H ldap://:400 -x

test1:
	# test1: default config, no seeds
	docker run -d --rm --name openldap_1 -p 401:389 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	ldapsearch -H ldap://:401 -xLLL -b dc=example,dc=com o=*
	docker stop openldap_1

test2:
	# test2: DOMAIN ROOTCN ROOTPW repeating default config, no seeds
	docker run -d --rm --name openldap_2 -p 402:389 \
	-e LDAP_DOMAIN=example.com \
	-e LDAP_ROOTCN=admin \
	-e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	ldapsearch -H ldap://:402 -xLLL -b dc=example,dc=com o=*
	docker stop openldap_2

test3:
	# test3: DOMAIN ROOTCN ROOTPW, no seeds
	docker run -d --rm --name openldap_3 -p 403:389 \
	-e LDAP_DOMAIN=ldap.my-domain.org \
	-e LDAP_ROOTCN=Manager \
	-e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	ldapsearch -H ldap://:403 -xLLL -b "dc=ldap,dc=my-domain,dc=org" o=*
	docker stop openldap_3

test4:
	# test4: default config, no seeds, from within add sha512.ldif
	docker run -d --rm --name openldap_4 -p 404:389 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	docker cp seed openldap_4:/var/lib/openldap/
	docker exec -it openldap_4 ldap add /var/lib/openldap/seed/b/sha512.ldif
	ldapsearch -H ldap://:404 -xLLL -b dc=example,dc=com o=*
	docker stop openldap_4

test5:
	# test5: default config, no seeds, ldapadd users.ldif
	docker run -d --rm --name openldap_5 -p 405:389 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	ldapadd -H ldap://:405 -x -D "cn=admin,dc=example,dc=com" -w 'secret' -f seed/b/users.ldif
	sleep 3
	ldapsearch -H ldap://:405 -xLLL -b "dc=example,dc=com" '(&(objectclass=person)(cn=Par Robert))' mail
	docker stop openldap_5

test6:
	# test6: default config, seed users.ldif
	docker create --rm --name openldap_6 -p 406:389 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	docker cp seed/a/1-users.ldif openldap_6:/var/lib/openldap/seed/1/
	docker cp seed/b/users.ldif openldap_6:/var/lib/openldap/seed/1/
	docker start openldap_6
	sleep 3
	ldapsearch -H ldap://:406 -xLLL -b "dc=example,dc=com" '(&(objectclass=person)(cn=Par Robert))' mail
	docker stop openldap_6

test7:
	# test7: DOMAIN, seed users.ldif
	docker create --rm --name openldap_7 -p 407:389 \
	-e LDAP_DOMAIN=directory.dotcom.info \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	docker cp seed/a/1-users.ldif openldap_7:/var/lib/openldap/seed/1/
	docker cp seed/b/users.ldif openldap_7:/var/lib/openldap/seed/1/
	docker start openldap_7
	sleep 3
	ldapsearch -H ldap://:407 -xLLL -b "dc=directory,dc=dotcom,dc=info" '(&(objectclass=person)(cn=Par Robert))' mail
	docker stop openldap_7

test8:
	# test8: seed config.ldif, seed users.ldif
	docker create --rm --name openldap_8 -p 408:389 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	docker cp seed/b/config.ldif openldap_8:/var/lib/openldap/seed/0/
	docker cp seed/a/1-users.ldif openldap_8:/var/lib/openldap/seed/1/
	docker cp seed/b/users.ldif openldap_8:/var/lib/openldap/seed/1/
	docker start openldap_8
	sleep 3
	ldapsearch -H ldap://:408 -xLLL -b "dc=example,dc=com" '(&(objectclass=person)(cn=Par Robert))' mail
	docker stop openldap_8

test9:
	# test9: DOMAIN ROOTCN ROOTPW, seed config.ldif, seed users.ldif
	docker create --rm --name openldap_8 -p 408:389 \
	-e LDAP_DOMAIN=ldap.my-domain.org \
	-e LDAP_ROOTCN=Manager \
	-e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	docker cp seed/b/config.ldif openldap_8:/var/lib/openldap/seed/0/
	docker cp seed/a/1-users.ldif openldap_8:/var/lib/openldap/seed/1/
	docker cp seed/b/users.ldif openldap_8:/var/lib/openldap/seed/1/
	docker start openldap_8
	sleep 3
	ldapsearch -H ldap://:408 -xLLL -b "dc=ldap,dc=my-domain,dc=org" '(&(objectclass=person)(cn=Par Robert))' mail
	docker stop openldap_8

