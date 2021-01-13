# Makefile
#
# demo
#

-include    *.mk .env

AD_BASE  ?= $(LDAPBASE)
AD_DOM   ?= $(call ad_sub_dot, $(AD_BASE))
AD_DC    ?= $(call ad_cut_dot, 1, 1, $(AD_DOM))

SSL_O     = $(AD_DOM)

SRV_IP   ?= $(call dkr_srv_ip, auth)
SRV_CNT  ?= $(call dkr_srv_cnt, auth)

srv_list ?= auth dns gui

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

init: up auth-init

test: auth-url_all

web:
	firefox localhost:8001 &

ps:
	docker-compose ps

up:
	docker-compose up -d

down:
	docker-compose down

destroy: ssl-destroy
	docker-compose down -v

config:
	docker-compose config

logs:
	docker-compose logs --tail 10

images:
	docker-compose images

$(addsuffix -up,$(srv_list)):
	docker-compose up -d $(patsubst %-up,%,$@)

$(addsuffix -create,$(srv_list)):
	docker-compose up --no-start $(patsubst %-create,%,$@)

$(addsuffix -down,$(srv_list)):
	docker-compose rm -s $(patsubst %-down,%,$@)

$(addsuffix -restart,$(srv_list)):
	docker-compose restart $(patsubst %-restart,%,$@)

$(addsuffix -start,$(srv_list)):
	docker-compose start $(patsubst %-start,%,$@)

$(addsuffix -renew,$(srv_list)):
	docker-compose rm -s $(patsubst %-renew,%,$@)
	docker-compose up -d $(patsubst %-renew,%,$@)

$(addsuffix -top,$(srv_list)):
	docker-compose top $(patsubst %-top,%,$@)

$(addsuffix -logs,$(srv_list)):
	docker-compose logs $(patsubst %-logs,%,$@)

$(addsuffix -pull,$(srv_list)):
	docker-compose pull $(patsubst %-pull,%,$@)

$(addsuffix -sh,$(srv_list)):
	docker-compose exec $(patsubst %-sh,%,$@) sh -c 'exec $$(getent passwd root | sed "s/.*://g")'

$(addsuffix -env,$(srv_list)):
	docker-compose exec $(patsubst %-env,%,$@) env

$(addsuffix -diff,$(srv_list)):
	docker container diff $(COMPOSE_PROJECT_NAME)_$(patsubst %-diff,%,$@)_1

$(addsuffix -hosts,$(srv_list)):
	docker-compose exec $(patsubst %-hosts,%,$@) cat /etc/hosts

wait_%:
	sleep $*

auth-init: wait_2 auth-mod_conf auth-add_data auth-add_ssl

define LDIF_MOD_CONF
dn: olcDatabase={-1}frontend,cn=config
changetype: modify
add: olcPasswordHash
olcPasswordHash: {CRYPT}

dn: cn=config
changetype: modify
add: olcPasswordCryptSaltFormat
olcPasswordCryptSaltFormat: $$6$$%.16s

dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: cn,ou,uid,mail eq
endef
export LDIF_MOD_CONF

define LDIF_ADD_DATA
dn: $(AD_BASE)
changetype: add
objectClass: organization
objectClass: dcObject
dc: $(AD_DC)
o: $(AD_DOM)

dn: ou=$(AD_USR_OU),$(AD_BASE)
changetype: add
objectClass: organizationalUnit
ou: $(AD_USR_OU)

dn: uid=$(AD_USR_CN),ou=$(AD_USR_OU),$(AD_BASE)
changetype: add
objectClass: $(AD_USR_OBJ)
cn: $(AD_USR_CN)
sn: $(AD_USR_CN)
uid: $(AD_USR_CN)
mail: $(AD_USR_CN)@$(AD_DOM)
userPassword: $(AD_USR_PW)
telephoneNumber: $(AD_USR_TEL)
title: $(AD_USR_TIT)
endef
export LDIF_ADD_DATA

define LDIF_ADD_SSL
dn: cn=config
changetype: modify
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /srv/ssl/ca.crt
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /srv/ssl/auth.key
-
add: olcTLSCertificateFile
olcTLSCertificateFile: /srv/ssl/auth.crt
-
add: olcTLSVerifyClient
olcTLSVerifyClient: demand
endef
export LDIF_ADD_SSL

auth-mod_conf:
	echo "$$LDIF_MOD_CONF" | docker-compose exec -T auth ldapmodify

auth-add_data:
	echo "$$LDIF_ADD_DATA" | docker-compose exec -T auth ldapmodify

auth-add_ssl: auth-cp_ssl
	echo "$$LDIF_ADD_SSL" | docker-compose exec -T auth ldapmodify

auth-cp_ssl: ssl/auth.crt ssl/demo.crt
	docker cp ssl $(call dkr_srv_cnt,auth):/srv/ssl

auth-show_conf:
	docker-compose exec auth ldapsearch -b cn=config "(cn=config)"
	docker-compose exec auth ldapsearch -b cn=config olcDatabase={-1}frontend
	docker-compose exec auth ldapsearch -b cn=config olcDatabase={1}mdb

auth-show_data:
	docker-compose exec auth ldapsearch

auth-show_cat0:
	docker-compose exec auth slapcat -n0

auth-show_cat1:
	docker-compose exec auth slapcat -n1

auth-show_debug:
	docker-compose exec auth slapd -d ?

auth-url_all: $(addprefix auth-url_, ldapi ldap ldaps starttls)

auth-url_ldapi:
	docker-compose exec auth ldapwhoami

auth-url_ldap:
	ldapwhoami -xH ldap://auth/

auth-url_ldaps:
	ldapwhoami -H ldaps://auth/

auth-url_starttls:
	ldapwhoami -ZZH ldap://auth/

auth-htop: auth-debugtools
	docker-compose exec auth htop

auth-debugtools:
	docker-compose exec auth apk --no-cache --update add \
	nano less lsof htop bind-tools iputils strace
