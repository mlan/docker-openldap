#!/bin/sh -e

#
# config
#

LDAP_CONFDIR=${LDAP_CONFDIR-/etc/openldap/slapd.d}
LDAP_DATADIR=${LDAP_DATADIR-/var/lib/openldap/openldap-data}
LDAP_MODULEDIR=${LDAP_MODULEDIR-/usr/lib/openldap}
LDAP_RUNDIR=${LDAP_RUNDIR-/var/run/openldap}
LDAP_SEEDDIRa=${LDAP_SEEDDIRa-/var/lib/openldap/seed/a}
LDAP_SEEDDIR0=${LDAP_SEEDDIR0-/var/lib/openldap/seed/0}
LDAP_SEEDDIR1=${LDAP_SEEDDIR1-/var/lib/openldap/seed/1}
LDAP_ROOTCN=${LDAP_ROOTCN-admin}

#
# Limiting the open file descritors prevent exessive memory consumption by slapd
#

ulimit -n 8192

#
# helpers
#

_escape() { echo $1 | sed 's|/|\\\/|g' ;}
_dc() { echo "$1" | sed 's/\./,dc=/g' ;}
_isadd() { [ -z "$(sed '1,5!d;/changetype: modify/!d;q' $1)" ] && echo "-a" ;} 
add() { 
	[ "$1" = "-f" ] && $2 "$3" && shift 2
	ldapmodify $(_isadd "$1") -Y EXTERNAL -H ldapi:/// -f "$1" 2>&1
}
addslap() { 
	[ "$1" = "-f" ] && $2 "$3" && shift 2
	slapadd -n 0 -F "$LDAP_CONFDIR" -l "$1" 2>&1
}

#
# ldif filters
#

ldif_intern() {
	# remove operational entries preventing file from being applied
	# since data files can be large, only process file 
	# if first entry contains an operational entry
	if [ -n "$(sed '/^dn/,/^$/!d;/entryUUID: /!d;q' $1)" ]; then
		sed -i.bak \
'/^structuralObjectClass/d;'\
'/^entryUUID/d;'\
'/^entryCSN/d;'\
'/^creatorsName/d;'\
'/^createTimestamp/d;'\
'/^modifiersName/d;'\
'/^modifyTimestamp/d' "$1"
	fi
}
ldif_paths() {
	sed -i \
'/^olcArgsFile:/s/\s.*/'" $(_escape $LDAP_RUNDIR)\/slapd.args"'/;'\
'/^olcPidFile:/s/\s.*/'" $(_escape $LDAP_RUNDIR)\/slapd.pid"'/;'\
'/^olcDbDirectory/s/\s.*/'" $(_escape $LDAP_DATADIR)"'/;'\
'/^olcModulePath/s/\s.*/'" $(_escape $LDAP_MODULEDIR)"'/;'\
'/^olcModuleLoad/s/\.la$//' "$1"
}
ldif_unwrap() { sed -i ':a;N;$!ba;s/\n //g' "$1" ;}
ldif_access() {
	# insert EXTENAL access if some database is missing it
	local EXTERNALACCESS='by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage'
	sed -i -r '/^olcAccess: .*to \* by .*/bX ; p ; d; :X /external/!s/(.*to \* )(by .*)/\1'"$EXTERNALACCESS"' \2/' "$1"
}
ldif_domain() {
	if [ ! -z "$LDAP_DOMAIN" ]; then 
		sed -i \
'/^olcSuffix:/s/\s.*/'" dc=$(_dc $LDAP_DOMAIN)"'/;'\
'/^olcRootDN:/s/\s.*/'" cn=$LDAP_ROOTCN,dc=$(_dc $LDAP_DOMAIN)"'/' "$1"
	fi
	if [ ! -z "$LDAP_ROOTPW" ]; then
		sed -i 's/^olcRootPW:.*/'"olcRootPW: $LDAP_ROOTPW"'/' "$1"
	fi
}
ldif_newdomain() {
	local domain=${2-$LDAP_DOMAIN}
	if [ ! -z "$domain" ]; then
		sed -i -r \
's/([a-z]+: )[ ]*(uid=[^,]*,)?[ ]*(cn=[^,]*,)?[ ]*(ou=[^,]*,)?[ ]*(dc=.*)/\1\2\3\4'"dc=$(_dc $domain)"'/;'\
's/^o: .*/o: '"$domain"'/;'\
's/^dc: .*/dc: '"${domain%%.*}"'/;'\
's/(^mail: [^@]*@).*/\1'"$domain"'/' "$1"
	fi
}
ldif_config() {
	ldif_intern "$1" &&
	ldif_paths  "$1" &&
	ldif_domain "$1" &&
	( [ -z "$LDAP_DONTADDEXTERNAL" ] && ldif_unwrap "$1" || true ) &&
	( [ -z "$LDAP_DONTADDEXTERNAL" ] && ldif_access "$1" || true )
}

#
# seed dirs search
#

load_all0() {
	# apply cofiguration file(s) if config is missing
	if [ ! -z "$(slaptest -Q 2>&1)" ]; then
		mkdir -p $LDAP_CONFDIR
		local files="$(find "$LDAP_SEEDDIR0" -type f -iname '*.ldif' -o -iname '*.sh' | sort)"
		if [ -z "$files" ]; then
			# no files found use default configuration
			mv $LDAP_SEEDDIRa/slapd.ldif $LDAP_SEEDDIR0/.
			files="$LDAP_SEEDDIR0/slapd.ldif"
		fi
		for file in $files ; do
			case "$file" in
			*.sh)   echo "$0: sourcing $file"; . "$file" ;;
			*.ldif) echo "$0: applying $file"; addslap -f "ldif_config" "$file" ;;
			esac
		done
		chown -R ldap:ldap $LDAP_CONFDIR
	fi
}
load_all1() {
	# apply files if slapd is running and data is empty
	if [ ! -z "$(pidof slapd)" ] && [ -z "$(slapcat -a '(o=*)')" ]; then
		for file in $(find "$LDAP_SEEDDIR1" -type f | sort); do
			case "$file" in
			*.sh)   echo "$0: sourcing $file"; . "$file" ;;
			*.ldif) echo "$0: applying $file"; add -f "ldif_intern" "$file" ;;
			*)      echo "$0: ignoring $file" ;;
			esac
		done
	else
		echo "$0: slapd is not running, but normally it should. Files in $LDAP_SEEDDIR1 (if any) are not applied"
	fi
}

#
# debug
#

help() { echo "
	ldap <cmd> <args>
	This command is a wrapper of the docker entrypoint shell script.
	Its purpuse is to ease container management and debugging.

	<cmd> group apply ldif
	add [-f <ldif filter>] <ldif file>
	addslap [-f <ldif filter>] <ldif file>

	<cmd> group apply seeds
	load_all0
	load_all1

	<cmd> group ldif filters:
	ldif_intern	<ldif file>
	ldif_paths 	<ldif file>
	ldif_unwrap	<ldif file>
	ldif_access	<ldif file>
	ldif_domain	<ldif file>
	ldif_config	<ldif file>
	ldif_newdomain	<ldif file> <domain>
	"
}
interactive() {
	if [ "$(basename $0)" = ldap ]; then
		if [ -n "$1" ]; then 
			$@
		else
			help
		fi
		exit 0
	fi
}

#
# run
#

interactive $@

#
# apply configurations
#
 
load_all0

#
# wait for slapd to start and then apply files in the backgroud
#

( sleep 2 ; load_all1 ) &

#
# start slapd if needed. if this shell is non interactive replace its process with slapd
#

if [ -z "$(pidof slapd)" ]; then
	exec slapd -d -256 -u ldap -g ldap -h "ldap:/// ldapi:///" -F $LDAP_CONFDIR
fi


