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
LDAP_LOGLEVEL=${LDAP_LOGLEVEL-2048}
VERBOSE=

#
# Infrom user
#

help() { echo "
	ldap <cmd> <args>
	This command is a wrapper of the docker entrypoint shell script.
	Its purpose is to ease container management and debugging.

	<cmd> group: ldap user
	ldap_chid [<uid:gid>]
	ldap_chown [-R]

	<cmd> group: apply ldif
	add0 [-f <ldif filter>] <ldif file>
	add [-f <ldif filter>] <ldif file>

	<cmd> group: apply ldif in seeding dirs
	add0_all
	add_all

	<cmd> group: ldif filters:
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

define_formats() {
	name=$(basename $0)
	f_norm="\e[0m"
	f_red="\e[91m"
	f_green="\e[92m"
	f_yellow="\e[93m"
}

inform() {
	local status=$1
	shift
	if [ $status == 0 -a -z "${VERBOSE+x}" ]; then
		status=-1
	fi
	case $status in
	0) echo -e "$f_bold${f_green}INFO ($name)${f_norm} $@" ;;
	1) echo -e "$f_bold${f_yellow}WARN ($name)${f_norm} $@" ;;
	2) echo -e "$f_bold${f_red}ERROR ($name)${f_norm} $@" && exit ;;
	esac
}

#
# Helpers
#

_escape() { echo $1 | sed 's|/|\\\/|g' ;}
_dc() { echo "$1" | sed 's/\./,dc=/g' ;}
_isadd() { [ -z "$(sed '1,1000!d;/changetype: /!d;q' $1)" ] && echo "-a" ;}
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
			mv $LDAP_SEEDDIRa/0* $LDAP_SEEDDIR0/.
			files="$(_findseed "$LDAP_SEEDDIR0")"
		fi
		for file in $files ; do
			case "$file" in
			*.sh)   inform 0 "Sourcing $file"; . "$file" ;;
			*.ldif) inform 0 "Applying $file"; add0 -f "ldif_config" "$file" ;;
			esac
		done
	else
		inform 0 "Slaptest OK. Files in $LDAP_SEEDDIR0 (if any) will not be reapplied"
	fi
}

add_all() {
	# Apply files if slapd is running and data is empty
	if [ ! -z "$(pidof slapd)" ] && [ -z "$(slapcat -a '(o=*)')" ]; then
		local files="$(_findseed "$LDAP_SEEDDIR1")"
		if [ -z "$files" ] && [ -z "$LDAP_DONTADDDCOBJECT" ]; then
			# no files found use default configuration
			mv $LDAP_SEEDDIRa/1* $LDAP_SEEDDIR1/.
			files="$(_findseed "$LDAP_SEEDDIR1")"
		fi
		for file in $files ; do
			case "$file" in
			*.sh)   inform 0 "Sourcing $file"; . "$file" ;;
			*.ldif) inform 0 "Applying $file"; add -f "ldif_users" "$file" ;;
			esac
		done
	else
		inform 1 "slapd is not running, but normally it should. Files in $LDAP_SEEDDIR1 (if any) are not applied"
	fi
}

#
# change ldap uid and gid
#

ldap_chid() {
	local uidgid=${1-$LDAP_UIDGID}
	# attempt to change ldap uid and gid only if LDAP_UIDGID is not empty
	if [ ! -z "$LDAP_UIDGID" ]; then
		uid=${uidgid%:*}
		local _gid=${uidgid#*:}
		gid=${_gid-$uid}
		# do not change ldap uid and gid if the uid is already set
		if [ ! $(getent passwd $uid > /dev/null) ]; then
			inform 0 "Will update ldap to $uid:$gid"
			deluser ldap
			addgroup -g $gid -S ldap
			adduser -u $uid -D -S -h /usr/lib/openldap -s /sbin/nologin -g 'OpenLDAP User' -G ldap ldap
		else
			inform 1 "NOT updating since ldap is $(id -u ldap):$(id -g ldap)"
		fi
	fi
}

#
# make sure ldap owns its files
#

ldap_chown() {
	# can use -R as argument
	chown "$1" ldap:ldap $LDAP_CONFDIR/..
	chown "$1" ldap:ldap $LDAP_USERDIR/..
	chown "$1" ldap:ldap $LDAP_RUNDIR
}

#
# debug
#

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

start() {
	# try to start slapd if it not running
	# if user provided any argument assume they are the desired start command
	if [ -z "$(pidof slapd)" ]; then
		if [[ $# -eq 0 ]] ; then
			cmd='slapd -u ldap -g ldap -h "ldap:/// ldapi:///"'
			if [ -n "$LDAP_CONFDIR" ]; then
				inform 0 Will use confdir $LDAP_CONFDIR
				cmd="${cmd} -F $LDAP_CONFDIR"
			fi
			if [ -n "$LDAP_LOGLEVEL" ]; then
				inform 0 Will use loglevel $LDAP_LOGLEVEL
				cmd="${cmd} -d $LDAP_LOGLEVEL"
			fi
		else
			cmd="$@"
		fi
		inform 0 Starting ldap using: $cmd
		exec $cmd
	fi
}

#
# Define colors for output
#

define_formats

#
# Limiting the open file descriptors prevent excessive memory consumption by slapd
#

ulimit -n 8192

#
# Allow interactive mode
#

interactive $@

#
# Potentially change ldap uid and gid
#

ldap_chid

#
# Apply configurations
#

add0_all
ldap_chown -R

#
# Wait for slapd to start and then apply files in the background
#

( sleep 2 ; add_all ) &

#
# Start slapd (if needed).
#

start $@
