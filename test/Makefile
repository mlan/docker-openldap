-include    *.mk

IMG_REPO ?= mlan/openldap
IMG_VER  ?= latest
_ip       = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

NET_NAME ?= test-net
NET_ENV  ?= --network $(NET_NAME)

AD_DOM1  ?= example.com
AD_DOM2  ?= ldap.my-domain.org
AD_DOM7  ?= directory.dotcom.info
AD_BAS1  ?= $(call ad_dn,$(AD_DOM1))
AD_BAS2  ?= $(call ad_dn,$(AD_DOM2))
AD_BAS7  ?= $(call ad_dn,$(AD_DOM7))
AD_ADM1  ?= admin
AD_ADM2  ?= Manager
AD_ADMPW ?= secret
AD_ADMSH ?= {SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3
AD_UID1  ?= 1001
AD_UID2  ?= 1002
AD_UOU   ?= users
AD_UOB   ?= posixAccount
AD_GOU   ?= groups
AD_FOU   ?= "(&(objectclass=$(AD_UOB))(mail=%s))"
AD_FPW   ?= "(&(objectclass=$(AD_UOB))(uid=%u))"
AD_APW   ?= uid=user


AUT_NAME ?= auth
AUT_DOM  ?= 
AUT_IMG  ?= $(IMG_REPO):$(IMG_VER)
AUT_PORT ?= 401
AUT_FQDN ?= $(AUT_NAME).$(AD_DOM1)
AUT_PUB  ?= -p $(AUT_PORT):389
AUT_VOL  ?=
AUT_ENV  ?= $(NET_ENV) $(AUT_PUB) \
--name $(AUT_NAME) \
--hostname $(AUT_FQDN)
VOL_ENV  ?= -v $(AUT_NAME):/srv
ADM1_ENV ?= \
-e LDAP_DOMAIN=$(AD_DOM1) \
-e LDAP_ROOTCN=$(AD_ADM1) \
-e LDAP_ROOTPW=$(AD_ADMSH)
ADM2_ENV ?= \
-e LDAP_DOMAIN=$(AD_DOM2) \
-e LDAP_ROOTCN=$(AD_ADM2) \
-e LDAP_ROOTPW=$(AD_ADMSH)
UID1_ENV ?= \
-e LDAP_UIDGID=$(AD_UID1)
UID2_ENV ?= \
-e LDAP_UIDGID=$(AD_UID2)
NOEX_ENV ?= \
-e LDAP_DONTADDEXTERNAL=true
NOOB_ENV ?= \
-e LDAP_DONTADDDCOBJECT=true
AUT7_ENV ?= $(AUT_ENV) \
-e LDAP_DOMAIN=$(AD_DOM7) \
-e LDAP_EMAILDOMAIN=gmail.com

ADD_ENV1 ?= \
-H ldap://:$(AUT_PORT) -x -D "cn=$(AD_ADM1),$(AD_BAS1)" -w $(AD_ADMPW)
TST_ENV ?= \
-H ldap://:$(AUT_PORT) -xLLL
TST1_ENV ?= $(TST_ENV) \
-b "$(AD_BAS1)" "o=*" \
| grep "dn: $(AD_BAS1)"
TST2_ENV ?= $(TST_ENV) \
-b "$(AD_BAS2)" "o=*" \
| grep "dn: $(AD_BAS2)"
TST3_ENV ?= $(TST_ENV) \
-b "$(AD_BAS1)" "(&(objectclass=person)(cn=Par Robert))" mail \
| grep 'mail: RobertP@ns-mail2.com'
TST7_ENV ?= $(TST_ENV) \
-b "$(AD_BAS7)" "(&(objectclass=person)(cn=Par Robert))" mail \
| grep 'mail: RobertP@gmail.com'
TST9_ENV ?= $(TST_ENV) \
-b "$(AD_BAS2)" "(&(objectclass=person)(cn=Harm Coddington))" mail \
| grep 'mail: CoddingH@ns-mail6.com'

CURL_OPT ?= -s -v
CURL_IMG ?= curlimages/curl
CURL_ENV ?= $(NET_ENV) \
-i --rm

TST_WAIT ?= 9

ps:
	docker ps -a

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

test-all: $(addprefix test_, 1 2 3 4 5 6 7 8 9)
	

test_%: test-up_% test-search_%
	

test-up_1:
	#
	#
	#
	# test (1) default config, no seeds, ldap and ldapi $(AD_BAS1)
	#
	#
	docker run -d $(AUT_ENV) $(AUT_IMG)
	sleep $(TST_WAIT)
	ldapsearch $(TST1_ENV)
	docker exec -it $(AUT_NAME) ldap search -b "$(AD_BAS1)" "o=*" \
	| grep "dn: $(AD_BAS1)"

test-up_2:
	#
	#
	#
	# test (2) DOMAIN ROOTCN ROOTPW UIDGID repeating default config, no seeds
	# test2: read only volume mount
	#
	#
	docker run -d $(AUT_ENV) $(VOL_ENV) $(ADM1_ENV) $(UID1_ENV) $(AUT_IMG)
	sleep $(TST_WAIT)
	docker stop $(AUT_NAME)
	docker start $(AUT_NAME)
	docker rm -f $(AUT_NAME)
	docker run -d $(AUT_ENV) $(VOL_ENV):ro $(UID2_ENV) $(AUT_IMG)
	sleep $(TST_WAIT)
	docker exec -it $(AUT_NAME) ls -lna /tmp/conf /tmp/data
	ldapsearch $(TST1_ENV)

test-up_3:
	#
	#
	#
	# test (3) DOMAIN ROOTCN ROOTPW, no seeds
	#
	#
	docker run -d $(AUT_ENV) $(ADM2_ENV) $(AUT_IMG)
	sleep $(TST_WAIT)
	ldapsearch $(TST2_ENV)

test-up_4:
	#
	#
	#
	# test (4) DONTADDEXTERNAL, no seeds, from within add sha512.ldif
	#
	#
	docker run -d $(AUT_ENV) $(NOEX_ENV) $(AUT_IMG)
	sleep $(TST_WAIT)
	docker cp seed/b $(AUT_NAME):/var/lib/openldap/seed/
	docker exec -it $(AUT_NAME) ldap add /var/lib/openldap/seed/b/181-sha512.ldif
	ldapsearch $(TST1_ENV)

test-up_5:
	#
	#
	#
	# test (5) DONTADDDCOBJECT, no seeds, ldapadd users.ldif
	#
	#
	docker run -d $(AUT_ENV) $(NOOB_ENV) $(AUT_IMG)
	sleep 1
	ldapadd $(ADD_ENV1) -f seed/a/110-dc.ldif
	ldapadd $(ADD_ENV1) -f seed/b/190-users.ldif >/dev/null
	sleep $(TST_WAIT)
	ldapsearch $(TST3_ENV)

test-up_6:
	#
	#
	#
	# test (6) default config, seed users.ldif
	#
	#
	docker create $(AUT_ENV) $(AUT_IMG)
	docker cp seed/a/110-dc.ldif $(AUT_NAME):/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif $(AUT_NAME):/var/lib/openldap/seed/1/
	docker start $(AUT_NAME)
	sleep $(TST_WAIT)
	ldapsearch $(TST3_ENV)

test-up_7:
	#
	#
	#
	# test (7) DOMAIN EMAILDOMAIN, seed users.ldif
	#
	#
	docker create $(AUT7_ENV) $(AUT_IMG)
	docker cp seed/a/110-dc.ldif $(AUT_NAME):/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif $(AUT_NAME):/var/lib/openldap/seed/1/
	docker start $(AUT_NAME)
	sleep $(TST_WAIT)
	ldapsearch $(TST7_ENV)

test-up_8:
	#
	#
	#
	# test (8) seed config.ldif, seed users.ldif
	#
	#
	docker create $(AUT_ENV) $(AUT_IMG)
	docker cp seed/b/009-config.ldif $(AUT_NAME):/var/lib/openldap/seed/0/
	docker cp seed/a/110-dc.ldif $(AUT_NAME):/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif $(AUT_NAME):/var/lib/openldap/seed/1/
	docker start $(AUT_NAME)
	sleep $(TST_WAIT)
	ldapsearch $(TST3_ENV)

test-up_9:
	#
	#
	#
	# test (9) DOMAIN ROOTCN ROOTPW, seed config.ldif, seed users.ldif, apply 191-user.ldif, 192-delete.ldif, 193-rename.ldif
	#
	#
	docker run -d $(AUT_ENV) $(ADM2_ENV) $(AUT_IMG)
	docker cp seed/b/009-config.ldif $(AUT_NAME):/var/lib/openldap/seed/0/
	docker cp seed/a/110-dc.ldif $(AUT_NAME):/var/lib/openldap/seed/1/
	docker cp seed/b/190-users.ldif $(AUT_NAME):/var/lib/openldap/seed/1/
	docker start $(AUT_NAME)
	sleep $(TST_WAIT)
	docker cp seed/b $(AUT_NAME):/var/lib/openldap/seed/
	docker exec -it $(AUT_NAME) ldap add -f 'ldif_users' /var/lib/openldap/seed/b/191-user.ldif
	docker exec -it $(AUT_NAME) ldap add -f 'ldif_users' /var/lib/openldap/seed/b/192-delete.ldif
	docker exec -it $(AUT_NAME) ldap add -f 'ldif_users' /var/lib/openldap/seed/b/193-rename.ldif
	ldapsearch $(TST9_ENV)

test-search_%:
	#
	#
	# test ($*) successful
	#
	#
	#
	docker rm -fv $(AUT_NAME) || true
	docker volume rm $(AUT_NAME) 2> /dev/null || true

test-down:
	docker rm -fv $(AUT_NAME) || true
	docker volume rm $(AUT_NAME) || true

test-env:
	docker exec -it $(AUT_NAME) env

test-logs:
	docker container logs $(AUT_NAME)

test-sh:
	docker exec -it $(AUT_NAME) sh -c 'exec $$(getent passwd root | sed "s/.*://g")'

test-diff:
	docker container diff $(AUT_NAME)

test-sv:
	docker exec -it $(AUT_NAME) sh -c 'sv status $$SVDIR/*'

test-debugtools:
	docker exec -it $(AUT_NAME) apt-get update
	docker exec -it $(AUT_NAME) apt-get install --yes \
	less nano ldap-utils htop net-tools lsof iputils-ping strace

test-htop: test-debugtools
	docker exec -it $(AUT_NAME) htop

test-seed_export:
	mkdir -p seed/0 seed/1
	sudo slapcat -n0 -o ldif-wrap=no -l seed/0/config.ldif
	sudo slapcat -n1 -o ldif-wrap=no -l seed/1/users.ldif

test-seed_import:
	docker cp seed $(AUT_NAME):/var/lib/openldap/
