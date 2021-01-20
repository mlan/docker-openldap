# Makefile
#
# test
#

-include    *.mk

TST_REPO ?= mlan/openldap
TST_VER  ?= latest

AD_DOM1  ?= example.com
AD_DOM2  ?= my-domain.org
AD_SUF1  ?= $(call ad_sub_dc,$(AD_DOM1))
AD_SUF2  ?= $(call ad_sub_dc,$(AD_DOM2))
AD_ADM1  ?= admin
AD_ADM2  ?= manager
AD_DN1   ?= $(call ad_cat_dn,$(AD_ADM1),$(AD_SUF1))
AD_DN2   ?= $(call ad_cat_dn,$(AD_ADM2),$(AD_SUF2))
AD_ADMPW ?= secret
AD_ADMSH ?= {SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3
AD_UOU   ?= users
AD_UOB   ?= posixAccount
AD_GOU   ?= groups
AD_FOU   ?= "(&(objectclass=$(AD_UOB))(mail=%s))"
AD_FPW   ?= "(&(objectclass=$(AD_UOB))(uid=%u))"
AD_APW   ?= uid=user
LIF_DIT1 ?= $(shell ls ldif/1/*.ldif)
LIF_DIT2 ?= ldif/sample/dit-$(AD_DOM2)-add.ldif
LIF_CFG1 ?= ldif/sample/cfg-sha512-mod.ldif

AUT_NAME ?= auth
AUT_DOM  ?=
AUT_IMG  ?= $(TST_REPO):$(TST_VER)
AUT_PORT ?= 401
AUT_FQDN ?= $(AUT_NAME).$(AD_DOM1)
AUT_PUB  ?= -p $(AUT_PORT):389
VDB_NAME ?= $(AUT_NAME)-db
VBK_NAME ?= $(AUT_NAME)-bak
VBK_PATH ?= $$(pwd)/ldif
AUT_UID1 ?= 1001:1011
AUT_UID2 ?= ldap
AUT_ENV  ?= $(AUT_PUB) \
--name $(AUT_NAME) \
--hostname $(AUT_FQDN) \
-e SYSLOG_LEVEL=7 \
--cap-add=sys_ptrace
VORW_ENV  ?= -v $(VDB_NAME):/srv
VORO_ENV  ?= -v $(VDB_NAME):/srv:ro
VOLB_ENV  ?= -v $(VBK_PATH):/ldif
VOLK_ENV  ?= -v $(VBK_NAME):/ldif
ADM1_ENV ?= \
-e LDAPBASE=$(AD_SUF1) \
-e LDAPROOT_CN=$(AD_DN1) \
-e LDAPROOT_PW=$(AD_ADMSH)
ADM2_ARG ?= \
--base $(AD_SUF2) --root-cn $(AD_ADM2) --root-pw $(AD_ADMSH)
UID1_ENV ?= \
-e LDAPRUNAS=$(AUT_UID1)
UID2_ENV ?= \
-e LDAPRUNAS=$(AUT_UID2)
NOEX_ENV ?= \
-e LDAP_DONTADDEXTERNAL=true
NOOB_ENV ?= \
-e LDAP_DONTADDDCOBJECT=true

GREP_ENV ?= --color=always

SRH_ENV ?= \
-H ldap://:$(AUT_PORT) -xLLL
BND1_ENV ?= \
-D $(AD_DN1) -w $(AD_ADMPW)
BND2_ENV ?= \
-D $(AD_DN2) -w $(AD_ADMPW)
TST0_ENV ?= \
-b cn=config '(olcAccess=*)' olcAccess olcSuffix \
| grep $(GREP_ENV) olcSuffix:
TST1_ENV ?= \
-b "$(AD_SUF1)" "o=*" \
| grep $(GREP_ENV) "dn: $(AD_SUF1)"
TST2_ENV ?= \
-b "$(AD_SUF2)" "o=*" \
| grep $(GREP_ENV) "dn: $(AD_SUF2)"

TST_WAIT ?= 5

ps:
	docker ps -a

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

test-all: $(addprefix test_, 1 2 3 4 5 6)
	

test_%: test-up_% test-finish_%
	

define test_db
	sleep $(TST_WAIT)
	docker container logs $(AUT_NAME)
	docker exec $(AUT_NAME) ldapsearch $(1)
	$(if $(2),ldapsearch $(SRH_ENV) $(2) $(1),)
endef

test-up_1:
	#
	#
	#
	# test (1)
	#	run w no envs, no args, no vols except $(VOLK_ENV)
	#
	#	ldapsearch ldapi://cn=config
	#
	docker run -d $(AUT_ENV) $(VOLK_ENV) $(AUT_IMG)
	$(call test_db,$(TST0_ENV))

test-up_2:
	#
	#
	#
	# test (2)
	#	run w no envs, no args, vols: $(VORW_ENV) $(VOLB_ENV)
	#	run w no envs, no args, vols: $(VORO_ENV)
	#
	#	ldapsearch ldapi://cn=config
	#	ldapsearch ldap://$(AD_SUF1)
	#
	docker run -d $(AUT_ENV) $(VORW_ENV) $(VOLB_ENV) $(AUT_IMG)
	$(call test_db,$(TST1_ENV),$(BND1_ENV))
	docker rm -f $(AUT_NAME)
	docker run -d $(AUT_ENV) $(VORO_ENV) $(AUT_IMG)
	docker exec -it $(AUT_NAME) ls -lna /tmp/conf /tmp/data
	$(call test_db,$(TST1_ENV),$(BND1_ENV))

test-up_3:
	#
	#
	#
	# test (3)
	#	run w no envs, no args, no vols
	#	exec ldapadd < $(LIF_DIT1)
	#	exec ldapmodify < $(LIF_CFG1)
	#
	#	ldapsearch ldapi://cn=config
	#	ldapsearch ldap://$(AD_SUF1)
	#
	docker run -d $(AUT_ENV) $(AUT_IMG)
	sleep $(TST_WAIT)
	docker exec -i $(AUT_NAME) ldapadd < $(LIF_DIT1) > /dev/null
	docker exec -i $(AUT_NAME) ldapmodify < $(LIF_CFG1) > /dev/null
	$(call test_db,$(TST1_ENV),$(BND1_ENV))

test-up_4:
	#
	#
	#
	# test (4)
	#	run w no envs, no vols, args $(ADM2_ARG)
	#	exec add < $(LIF_DIT2)
	#
	#	ldapsearch ldapi://cn=config
	#	ldapsearch ldap://$(AD_SUF2)
	#
	#
	docker run -d $(AUT_ENV) $(AUT_IMG) $(ADM2_ARG)
	sleep $(TST_WAIT)
	docker exec -i $(AUT_NAME) ldapadd < $(LIF_DIT2) > /dev/null
	$(call test_db,$(TST2_ENV),$(BND2_ENV))

test-up_5:
	#
	#
	#
	# test (5)
	#	create w no envs, no args, no vols
	#	cp $(VBK_PATH)
	#	start
	#
	#	ldapsearch ldapi://cn=config
	#	ldapsearch ldap://$(AD_SUF1)
	#
	docker create $(AUT_ENV) $(AUT_IMG)
	docker cp $(VBK_PATH) $(AUT_NAME):/
	docker start $(AUT_NAME)
	$(call test_db,$(TST1_ENV),$(BND1_ENV))

test-up_6:
	#
	#
	#
	# test (6)
	#	run w no envs, args  $(UID1_ENV), vols: $(VORW_ENV) $(VOLB_ENV)
	#	run w no envs, args  $(UID2_ENV), vols: $(VORW_ENV)
	#
	#	ldapsearch ldapi://cn=config
	#	ldapsearch ldap://$(AD_SUF1)
	#
	docker run -d $(AUT_ENV) $(VORW_ENV) $(VOLB_ENV) $(UID1_ENV) $(AUT_IMG)
	docker exec -it $(AUT_NAME) ls -l /srv
	$(call test_db,$(TST1_ENV),$(BND1_ENV))
	docker rm -f $(AUT_NAME)
	docker run -d $(AUT_ENV) $(VORW_ENV) $(UID2_ENV) $(AUT_IMG)
	docker exec -it $(AUT_NAME) ls -l /srv
	$(call test_db,$(TST1_ENV),$(BND1_ENV))

test-finish_%: test-down_%
	#
	#
	# test ($*) success ☺
	#
	#
	#

test-down: test-down_0

test-down_%:
	docker rm -fv $(AUT_NAME) || true
	docker volume rm $(VDB_NAME) $(VBK_NAME) 2> /dev/null || true

test-cat0:
	docker exec -it $(AUT_NAME) slapcat -n 0 -o ldif-wrap=no

test-cat1:
	docker exec -it $(AUT_NAME) slapcat -n 1 -o ldif-wrap=no

test-debugtools:
	docker exec $(AUT_NAME) apk --no-cache --update add \
	nano less lsof htop openldap-clients bind-tools iputils strace

test-diff:
	docker container diff $(AUT_NAME)

test-env:
	docker exec $(AUT_NAME) env

test-htop: test-debugtools
	docker exec -it $(AUT_NAME) htop

test-logs:
	docker container logs $(AUT_NAME)

test-netstat: test-debugtools
	docker exec -it $(AUT_NAME) netstat -apnt

test-search0:
	ldapsearch $(SRH_ENV) $(TST0_ENV)

test-search1:
	ldapsearch $(SRH_ENV) $(TST1_ENV)

test-sh:
	docker exec -it $(AUT_NAME) sh -c 'exec $$(getent passwd root | sed "s/.*://g")'

test-top:
	docker exec -it $(AUT_NAME) top

host-backup:
	docker run --name tmp -it -d $(VOLK_ENV) alpine sh
	docker exec tmp mkdir -p /ldif/0 /ldif/1
	sudo slapcat -n 0 -o ldif-wrap=no | docker exec -i tmp sh -c \
	"cat > /ldif/0/cfg.host.ldif"
	sudo slapcat -n 1 -o ldif-wrap=no | docker exec -i tmp sh -c \
	"cat > /ldif/1/dit.host.ldif"
	docker rm -f tmp
