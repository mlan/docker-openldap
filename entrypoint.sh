#!/bin/sh -e

#
# Config
#

LDAP_CONFDIR=${LDAP_CONFDIR-/etc/openldap/slapd.d}
LDAP_USERDIR=${LDAP_USERDIR-/var/lib/openldap/openldap-data}
LDAP_MODULEDIR=${LDAP_MODULEDIR-/usr/lib/openldap}
LDAP_RUNDIR=${LDAP_RUNDIR-/var/run/openldap}
LDAP_SEEDDIRa=${LDAP_SEEDDIRa-/var/lib/openldap/seed/a}
LDAP_SEEDDIR0=${LDAP_SEEDDIR0-/var/lib/openldap/seed/0}
LDAP_SEEDDIR1=${LDAP_SEEDDIR1-/var/lib/openldap/seed/1}
LDAP_ROOTCN=${LDAP_ROOTCN-admin}

#
# Helpers
#

_escape() { echo $1 | sed 's|/|\\\/|g' ;}
_dc() { echo "$1" | sed 's/\./,dc=/g' ;}
_isadd() { [ -z "$(sed '1,5!d;/changetype: modify/!d;q' $1)" ] && echo "-a" ;} 
_findseed() { find "$1" -type f -iname '*.ldif' -o -iname '*.sh' | sort ;}
add() { 
	[ "$1" = "-f" ] && $2 "$3" && shift 2
	ldapmodify $(_isadd "$1") -Y EXTERNAL -H ldapi:/// -f "$1" 2>&1
}
add0() { 
	[ "$1" = "-f" ] && $2 "$3" && shift 2
	slapadd -n 0 -F "$LDAP_CONFDIR" -l "$1" 2>&1
}

#
# LDIF filters
#

ldif_intern() {
	# Remove operational entries preventing file from being applied
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
'/^olcDbDirectory/s/\s.*/'" $(_escape $LDAP_USERDIR)"'/;'\
'/^olcModulePath/s/\s.*/'" $(_escape $LDAP_MODULEDIR)"'/;'\
'/^olcModuleLoad/s/\.la$//' "$1"
}
ldif_unwrap() { sed -i ':a;N;$!ba;s/\n //g' "$1" ;}
ldif_access() {
	# insert EXTERNAL access if some database is missing it
	local EXTERNALACCESS='by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage'
	sed -i -r '/^olcAccess: .*to \* by .*/bX ; p ; d; :X /external/!s/(.*to \* )(by .*)/\1'"$EXTERNALACCESS"' \2/' "$1"
}
ldif_suffix() {
	local domain=${2-$LDAP_DOMAIN}
	local rootcn=${3-$LDAP_ROOTCN}
	local rootpw=${4-$LDAP_ROOTPW}
	if [ ! -z "$domain" ]; then 
		sed -i \
'/^olcSuffix:/s/\s.*/'" dc=$(_dc $domain)"'/;'\
'/^olcRootDN:/s/\s.*/'" cn=$rootcn,dc=$(_dc $domain)"'/' "$1"
	fi
	if [ ! -z "$rootpw" ]; then
		sed -i 's/^olcRootPW:.*/'"olcRootPW: $rootpw"'/' "$1"
	fi
}
ldif_domain() {
	local domain=${2-$LDAP_DOMAIN}
	if [ ! -z "$domain" ]; then
		sed -i -r \
's/([a-z]+: )[ ]*(uid=[^,]*,)?[ ]*(cn=[^,]*,)?[ ]*(ou=[^,]*,)?[ ]*(dc=.*)/\1\2\3\4'"dc=$(_dc $domain)"'/;'\
's/^o: .*/o: '"$domain"'/;'\
's/^dc: .*/dc: '"${domain%%.*}"'/' "$1"
	fi
}
ldif_email() {
	local domain=${2-$LDAP_EMAILDOMAIN}
	if [ ! -z "$domain" ]; then
		sed -i -r 's/(^mail: [^@]*@).*/\1'"$domain"'/' "$1"
	fi
}
ldif_config() {
	ldif_intern "$1" &&
	ldif_paths  "$1" &&
	ldif_suffix "$1" &&
	( [ -z "$LDAP_DONTADDEXTERNAL" ] && ldif_unwrap "$1" || true ) &&
	( [ -z "$LDAP_DONTADDEXTERNAL" ] && ldif_access "$1" || true )
}
ldif_users() {
	ldif_intern "$1" &&
	ldif_domain "$1" &&
	ldif_email  "$1"
}

#
# Search seed directories and apply files
#

add0_all() {
	# Apply configuration file(s) if config is missing
	if [ ! -z "$(slaptest -Q 2>&1)" ]; then
		mkdir -p $LDAP_CONFDIR
		local files="$(_findseed "$LDAP_SEEDDIR0")"
		if [ -z "$files" ]; then
			# no files found use default configuration
			mv $LDAP_SEEDDIRa/0-* $LDAP_SEEDDIR0/.
			files="$(_findseed "$LDAP_SEEDDIR0")"
		fi
		for file in $files ; do
			case "$file" in
			*.sh)   echo "$0: sourcing $file"; . "$file" ;;
			*.ldif) echo "$0: applying $file"; add0 -f "ldif_config" "$file" ;;
			esac
		done
		chown -R ldap:ldap $LDAP_CONFDIR
	fi
}
add_all() {
	# Apply files if slapd is running and data is empty
	if [ ! -z "$(pidof slapd)" ] && [ -z "$(slapcat -a '(o=*)')" ]; then
		local files="$(_findseed "$LDAP_SEEDDIR1")"
		if [ -z "$files" ] && [ -z "$LDAP_DONTADDDCOBJECT" ]; then
			# no files found use default configuration
			mv $LDAP_SEEDDIRa/1-* $LDAP_SEEDDIR1/.
			files="$(_findseed "$LDAP_SEEDDIR1")"
		fi
		for file in $files ; do
			case "$file" in
			*.sh)   echo "$0: sourcing $file"; . "$file" ;;
			*.ldif) echo "$0: applying $file"; add -f "ldif_users" "$file" ;;
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
	Its purpose is to ease container management and debugging.

	<cmd> group apply ldif
	add0 [-f <ldif filter>] <ldif file>
	add [-f <ldif filter>] <ldif file>

	<cmd> group apply ldif in seeding dirs
	add0_all
	add_all

	<cmd> group ldif filters:
	ldif_intern	<ldif file>
	ldif_paths 	<ldif file>
	ldif_unwrap	<ldif file>
	ldif_access	<ldif file>
	ldif_suffix	<ldif file> <domain> <rootcn> <rootpw>
	ldif_domain	<ldif file> <domain>
	ldif_email	<ldif file> <domain>
	ldif_config	<ldif file>
	ldif_users	<ldif file>
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
# Limiting the open file descriptors prevent excessive memory consumption by slapd
#

ulimit -n 8192

#
# Run
#

interactive $@

#
# Apply configurations
#
 
add0_all

#
# Wait for slapd to start and then apply files in the background
#

( sleep 2 ; add_all ) &

#
# Start slapd if needed.
#

if [ -z "$(pidof slapd)" ]; then
	exec slapd -d -256 -u ldap -g ldap -h "ldap:/// ldapi:///" -F $LDAP_CONFDIR
fi


