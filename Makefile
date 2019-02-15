-include    *.mk

BLD_ARG  ?= --build-arg DIST=alpine --build-arg REL=3.9

IMG_REPO ?= mlan/openldap
IMG_VER  ?= latest
IMG_CMD  ?= /bin/sh

TST_PORT ?= 389
CNT_NAME ?= postfix-amavis-default
CNT_PORT ?= -p $(TST_PORT):389
CNT_ENV  ?=
CNT_VOL  ?=
CNT_DRV  ?=

TST_WAIT ?= 9

.PHONY: ps build build-force push shell cmd logs run run-fg run-force start stop rm-container rm-image purge export create testall test1 test2 test3 test4 test5 test6 test7 test8 test9

init: export create wait import start

ps:
	docker ps -a

build: Dockerfile
	docker build $(BLD_ARG) -t $(IMG_REPO):$(IMG_VER) .

build-force: stop purge build

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

push:
	docker push $(IMG_REPO)\:$(IMG_VER)

cmd:
	docker exec -it $(CNT_NAME) $(IMG_CMD)

run:
	docker run --rm -d --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_DRV) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER)

run-fg:
	docker run --rm --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_DRV) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER)

run-force:
	docker run -d --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_DRV) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER) while true; do sleep 86400; done

create:
	docker create  --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_DRV) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER)

logs:
	docker container logs $(CNT_NAME)

diff:
	docker container diff $(CNT_NAME)

start:
	docker start $(CNT_NAME)

stop:
	docker stop $(CNT_NAME)

purge: rm-container rm-image

rm-container:
	docker rm $(CNT_NAME)

rm-image:
	docker image rm $(IMG_REPO):$(IMG_VER)

export:
	mkdir -p seed/0 seed/1
	sudo slapcat -n0 -o ldif-wrap=no -l seed/0/config.ldif
	sudo slapcat -n1 -o ldif-wrap=no -l seed/1/users.ldif

import:
	docker cp seed $(CNT_NAME):/var/lib/openldap/

purge: rm-container rm-image

testall: test1 test2 test3 test4 test5 test6 test7 test8 test9

test1:
	# test1: default config, no seeds, ldap and ldapi
	docker run -d --rm --name openldap_1 -p 401:389 $(IMG_REPO):$(IMG_VER)
	sleep $(TST_WAIT)
	ldapsearch -H ldap://:401 -xLLL -b "dc=example,dc=com" "o=*" \
	| grep 'dn: dc=example,dc=com'
	docker exec -it openldap_1 ldap search -b "dc=example,dc=com" "o=*" \
	| grep 'dn: dc=example,dc=com'
	docker stop openldap_1

test2:
	# test2: DOMAIN ROOTCN ROOTPW UIDGID repeating default config, no seeds
	# test2: read only volume mount
	docker run -d --name openldap_2 -p 402:389 -v openldap_2:/srv \
	-e LDAP_DOMAIN=example.com \
	-e LDAP_ROOTCN=admin \
	-e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
	-e LDAP_UIDGID=1001 \
	$(IMG_REPO):$(IMG_VER)
	sleep $(TST_WAIT)
	docker stop openldap_2
	docker start openldap_2
	docker stop openldap_2
	docker rm openldap_2
	docker run -d --name openldap_2 -p 402:389 -v openldap_2:/srv:ro \
	-e LDAP_UIDGID=1002 \
	$(IMG_REPO):$(IMG_VER)
	sleep $(TST_WAIT)
	docker exec -it openldap_2 ls -lna /tmp/conf /tmp/data
	ldapsearch -H ldap://:402 -xLLL -b "dc=example,dc=com" "o=*" \
	| grep 'dn: dc=example,dc=com'
	docker stop openldap_2
	docker rm openldap_2
	docker volume rm openldap_2

test3:
	# test3: DOMAIN ROOTCN ROOTPW, no seeds
	docker run -d --rm --name openldap_3 -p 403:389 \
	-e LDAP_DOMAIN=ldap.my-domain.org \
	-e LDAP_ROOTCN=Manager \
	-e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
	$(IMG_REPO):$(IMG_VER)
	sleep $(TST_WAIT)
	ldapsearch -H ldap://:403 -xLLL -b "dc=ldap,dc=my-domain,dc=org" "o=*" \
	| grep 'dn: dc=ldap,dc=my-domain,dc=org'
	docker stop openldap_3

test4:
	# test4: DONTADDEXTERNAL, no seeds, from within add sha512.ldif
	docker run -d --rm --name openldap_4 -p 404:389 \
	-e LDAP_DONTADDEXTERNAL=true \
	$(IMG_REPO):$(IMG_VER)
	sleep $(TST_WAIT)
	docker cp seed/b openldap_4:/var/lib/openldap/seed/
	docker exec -it openldap_4 ldap add /var/lib/openldap/seed/b/181-sha512.ldif
	ldapsearch -H ldap://:404 -xLLL -b "dc=example,dc=com" "o=*" \
	| grep 'dn: dc=example,dc=com'
	docker stop openldap_4

test5:
	# test5: DONTADDDCOBJECT, no seeds, ldapadd users.ldif
	docker run -d --rm --name openldap_5 -p 405:389 \
	-e LDAP_DONTADDDCOBJECT=true \
	$(IMG_REPO):$(IMG_VER)
	sleep 1
	ldapadd -H ldap://:405 -x -D "cn=admin,dc=example,dc=com" -w 'secret' -f seed/a/110-dc.ldif
	ldapadd -H ldap://:405 -x -D "cn=admin,dc=example,dc=com" -w 'secret' -f seed/b/190-users.ldif >/dev/null
	sleep $(TST_WAIT)
	ldapsearch -H ldap://:405 -xLLL -b "dc=example,dc=com" \
	"(&(objectclass=person)(cn=Par Robert))" mail \
	| grep 'mail: RobertP@ns-mail2.com'
	docker stop openldap_5

test6:
	# test6: default config, seed users.ldif
	docker create --rm --name openldap_6 -p 406:389 \
	$(IMG_REPO):$(IMG_VER)
	docker cp seed/a/110-dc.ldif openldap_6:/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif openldap_6:/var/lib/openldap/seed/1/
	docker start openldap_6
	sleep $(TST_WAIT)
	ldapsearch -H ldap://:406 -xLLL -b "dc=example,dc=com" \
	"(&(objectclass=person)(cn=Par Robert))" mail \
	| grep 'mail: RobertP@ns-mail2.com'
	docker stop openldap_6

test7:
	# test7: DOMAIN EMAILDOMAIN, seed users.ldif
	docker create --rm --name openldap_7 -p 407:389 \
	-e LDAP_DOMAIN=directory.dotcom.info \
	-e LDAP_EMAILDOMAIN=gmail.com \
	$(IMG_REPO):$(IMG_VER)
	docker cp seed/a/110-dc.ldif openldap_7:/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif openldap_7:/var/lib/openldap/seed/1/
	docker start openldap_7
	sleep $(TST_WAIT)
	ldapsearch -H ldap://:407 -xLLL -b "dc=directory,dc=dotcom,dc=info" \
	"(&(objectclass=person)(cn=Par Robert))" mail \
	| grep 'mail: RobertP@gmail.com'
	docker stop openldap_7

test8:
	# test8: seed config.ldif, seed users.ldif
	docker create --rm --name openldap_8 -p 408:389 \
	$(IMG_REPO):$(IMG_VER)
	docker cp seed/b/009-config.ldif openldap_8:/var/lib/openldap/seed/0/
	docker cp seed/a/110-dc.ldif openldap_8:/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif openldap_8:/var/lib/openldap/seed/1/
	docker start openldap_8
	sleep $(TST_WAIT)
	ldapsearch -H ldap://:408 -xLLL -b "dc=example,dc=com" \
	"(&(objectclass=person)(cn=Par Robert))" mail \
	| grep 'mail: RobertP@ns-mail2.com'
	docker stop openldap_8

test9:
	# test9: DOMAIN ROOTCN ROOTPW, seed config.ldif, seed users.ldif, apply 191-user.ldif, 192-delete.ldif, 193-rename.ldif
	docker create --rm --name openldap_9 -p 409:389 \
	-e LDAP_DOMAIN=ldap.my-domain.org \
	-e LDAP_ROOTCN=Manager \
	-e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
	$(IMG_REPO):$(IMG_VER)
	docker cp seed/b/009-config.ldif openldap_9:/var/lib/openldap/seed/0/
	docker cp seed/a/110-dc.ldif openldap_9:/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif openldap_9:/var/lib/openldap/seed/1/
	docker start openldap_9
	sleep $(TST_WAIT)
	docker cp seed/b openldap_9:/var/lib/openldap/seed/
	docker exec -it openldap_9 ldap add -f 'ldif_users' /var/lib/openldap/seed/b/191-user.ldif
	docker exec -it openldap_9 ldap add -f 'ldif_users' /var/lib/openldap/seed/b/192-delete.ldif
	docker exec -it openldap_9 ldap add -f 'ldif_users' /var/lib/openldap/seed/b/193-rename.ldif
	ldapsearch -H ldap://:409 -xLLL -b "dc=ldap,dc=my-domain,dc=org" \
	"(&(objectclass=person)(cn=Harm Coddington))" mail \
	| grep 'mail: CoddingH@ns-mail6.com'
	docker stop openldap_9

