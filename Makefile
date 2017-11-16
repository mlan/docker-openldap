include make_env

NS ?= mlan
VERSION ?= latest

IMAGE_NAME ?= openldap
CONTAINER_NAME ?= openldap
CONTAINER_INSTANCE ?= default
SHELL ?= /bin/sh

.PHONY: build build-version build-all dockerfile build-force push shell exec run run-fg start stop rm-container rm-image purge release export copy create  sleep testall testall-all test1 test2 test3 test4 test5 test6 test7 test8 test9

build: 
	docker build -t $(NS)/$(IMAGE_NAME):$(VERSION) -f Dockerfile .

build-force: stop purge build

build-version: dockerfile
	docker build -t $(NS)/$(IMAGE_NAME):$(VERSION) -f $(VERSION)/Dockerfile $(VERSION)/.

build-all: build
	for ver in 3.6 3.5 3.4; do $(MAKE) build-version -e VERSION=$$ver; done
	
dockerfile:
	mkdir -p $(VERSION)/seed
	sed -r 's/(FROM\s*alpine)/\1:'"$(VERSION)"'/' Dockerfile >$(VERSION)/Dockerfile
	cp entrypoint.sh $(VERSION)/entrypoint.sh
	cp -r seed/a $(VERSION)/seed/a/

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

testall: test1 test2 test3 test4 test5 test6 test7 test8 test9 

testall-all: testall
	for ver in 3.6 3.5 3.4; do $(MAKE) testall -e VERSION=$$ver; done	

test1:
	# test1: default config, no seeds
	docker run -d --rm --name openldap_1 -p 401:389 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	ldapsearch -H ldap://:401 -xLLL -b "dc=example,dc=com" o=* \
	| grep 'dn: dc=example,dc=com'
	docker stop openldap_1

test2:
	# test2: DOMAIN ROOTCN ROOTPW repeating default config, no seeds
	docker run -d --rm --name openldap_2 -p 402:389 \
	-e LDAP_DOMAIN=example.com \
	-e LDAP_ROOTCN=admin \
	-e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	ldapsearch -H ldap://:402 -xLLL -b "dc=example,dc=com" o=* \
	| grep 'dn: dc=example,dc=com'
	docker stop openldap_2

test3:
	# test3: DOMAIN ROOTCN ROOTPW, no seeds
	docker run -d --rm --name openldap_3 -p 403:389 \
	-e LDAP_DOMAIN=ldap.my-domain.org \
	-e LDAP_ROOTCN=Manager \
	-e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	ldapsearch -H ldap://:403 -xLLL -b "dc=ldap,dc=my-domain,dc=org" o=* \
	| grep 'dn: dc=ldap,dc=my-domain,dc=org'
	docker stop openldap_3

test4:
	# test4: DONTADDEXTERNAL, no seeds, from within add sha512.ldif
	docker run -d --rm --name openldap_4 -p 404:389 \
	-e LDAP_DONTADDEXTERNAL=true \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	docker cp seed openldap_4:/var/lib/openldap/
	docker exec -it openldap_4 ldap add /var/lib/openldap/seed/b/181-sha512.ldif
	ldapsearch -H ldap://:404 -xLLL -b "dc=example,dc=com" o=* \
	| grep 'dn: dc=example,dc=com'
	docker stop openldap_4

test5:
	# test5: DONTADDDCOBJECT, no seeds, ldapadd users.ldif
	docker run -d --rm --name openldap_5 -p 405:389 \
	-e LDAP_DONTADDDCOBJECT=true \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	sleep 3
	ldapadd -H ldap://:405 -x -D "cn=admin,dc=example,dc=com" -w 'secret' -f seed/a/110-dc.ldif
	ldapadd -H ldap://:405 -x -D "cn=admin,dc=example,dc=com" -w 'secret' -f seed/b/190-users.ldif >/dev/null
	sleep 3
	ldapsearch -H ldap://:405 -xLLL -b "dc=example,dc=com" '(&(objectclass=person)(cn=Par Robert))' mail \
	| grep 'mail: RobertP@ns-mail2.com'
	docker stop openldap_5

test6:
	# test6: default config, seed users.ldif
	docker create --rm --name openldap_6 -p 406:389 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	docker cp seed/a/110-dc.ldif openldap_6:/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif openldap_6:/var/lib/openldap/seed/1/
	docker start openldap_6
	sleep 3
	ldapsearch -H ldap://:406 -xLLL -b "dc=example,dc=com" \ 
	'(&(objectclass=person)(cn=Par Robert))' mail \
	| grep 'mail: RobertP@ns-mail2.com'
	docker stop openldap_6

test7:
	# test7: DOMAIN EMAILDOMAIN, seed users.ldif
	docker create --rm --name openldap_7 -p 407:389 \
	-e LDAP_DOMAIN=directory.dotcom.info \
	-e LDAP_EMAILDOMAIN=gmail.com \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	docker cp seed/a/110-dc.ldif openldap_7:/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif openldap_7:/var/lib/openldap/seed/1/
	docker start openldap_7
	sleep 3
	ldapsearch -H ldap://:407 -xLLL -b "dc=directory,dc=dotcom,dc=info" \
	'(&(objectclass=person)(cn=Par Robert))' mail \
	| grep 'mail: RobertP@gmail.com'
	docker stop openldap_7

test8:
	# test8: seed config.ldif, seed users.ldif
	docker create --rm --name openldap_8 -p 408:389 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	docker cp seed/b/009-config.ldif openldap_8:/var/lib/openldap/seed/0/
	docker cp seed/a/110-dc.ldif openldap_8:/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif openldap_8:/var/lib/openldap/seed/1/
	docker start openldap_8
	sleep 3
	ldapsearch -H ldap://:408 -xLLL -b "dc=example,dc=com" \
	'(&(objectclass=person)(cn=Par Robert))' mail \
	| grep 'mail: RobertP@ns-mail2.com'
	docker stop openldap_8

test9:
	# test9: DOMAIN ROOTCN ROOTPW, seed config.ldif, seed users.ldif
	docker create --rm --name openldap_9 -p 409:389 \
	-e LDAP_DOMAIN=ldap.my-domain.org \
	-e LDAP_ROOTCN=Manager \
	-e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
	$(NS)/$(IMAGE_NAME):$(VERSION)
	docker cp seed/b/009-config.ldif openldap_9:/var/lib/openldap/seed/0/
	docker cp seed/a/110-dc.ldif openldap_9:/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif openldap_9:/var/lib/openldap/seed/1/
	docker start openldap_9
	sleep 3
	docker cp seed/b openldap_9:/var/lib/openldap/seed/
	#docker cp seed/b/192-delete.ldif openldap_9:/var/lib/openldap/seed/b/
	#docker cp seed/b/193-rename.ldif openldap_9:/var/lib/openldap/seed/b/
	docker exec -it openldap_9 ldap add -f 'ldif_users' /var/lib/openldap/seed/b/191-user.ldif
	docker exec -it openldap_9 ldap add -f 'ldif_users' /var/lib/openldap/seed/b/192-delete.ldif
	docker exec -it openldap_9 ldap add -f 'ldif_users' /var/lib/openldap/seed/b/193-rename.ldif
	ldapsearch -H ldap://:409 -xLLL -b "dc=ldap,dc=my-domain,dc=org" \
	'(&(objectclass=person)(cn=Harm Coddington))' mail \
	| grep 'mail: CoddingH@ns-mail6.com'
	docker stop openldap_9

