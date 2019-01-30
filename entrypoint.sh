#!/bin/sh -e

#
# TODO
# 1) update help
# 2) explore if seeding can be done better. Now we need to create, copy, start
#

#
# Config
#

LDAP_CONFDIR=${LDAP_CONFDIR-/etc/openldap/slapd.d}
LDAP_DATADIR=${LDAP_DATADIR-/var/lib/openldap/openldap-data}
LDAP_RUNDIR=${LDAP_RUNDIR-/var/run/openldap}
LDAP_IPCSOCK=${LDAP_IPCSOCK-$LDAP_RUNDIR/ldapi}
LDAP_MODULEDIR=${LDAP_MODULEDIR-/usr/lib/openldap}
LDAP_SEEDDIRa=${LDAP_SEEDDIRa-/var/lib/openldap/seed/a}
LDAP_SEEDDIR0=${LDAP_SEEDDIR0-/var/lib/openldap/seed/0}
LDAP_SEEDDIR1=${LDAP_SEEDDIR1-/var/lib/openldap/seed/1}
LDAP_ROOTCN=${LDAP_ROOTCN-admin}
LDAP_LOGLEVEL=${LDAP_LOGLEVEL-2048}
LDAP_CONFVOL=${LDAP_CONFVOL-/srv/conf}
LDAP_DATAVOL=${LDAP_DATAVOL-/srv/data}
LDAP_RWCOPYDIR=${LDAP_RWCOPYDIR-/tmp}
LDAP_USER=${LDAP_USER-ldap}
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

_escdiv() { echo $1 | sed 's|/|\\\/|g' ;}
_escurl() { echo $1 | sed 's|/|%2F|g' ;}
_dc() { echo "$1" | sed 's/\./,dc=/g' ;}
_isadd() { [ -z "$(sed '1,1000!d;/changetype: /!d;q' $1)" ] && echo "-a" ;}
_findseed() { find "$1" -type f -iname '*.ldif' -o -iname '*.sh' | sort ;}
_arg() { [[ -n "$2" ]] && echo "$1 $2" ;}
#_howmnt() { sed -nr 's/[^ ]+ '"$(_escdiv $1)"' [^ ]+ ([^,]+).*/\1/p' /proc/mounts ;}

_howmnt() {
	# search if arg is mentioned in /proc/mounts and return its mount options
	# if arg is not mentioned try its parent directory
	# make sure arg is absolute path
	local dir=/${1#/}
	local mntopt=
	while [ -n "$dir" -a -z "$mntopt" ]; do
		mntopt=$(sed -nr 's/[^ ]+ '"$(_escdiv $dir)"' [^ ]+ ([^,]+).*/\1/p' /proc/mounts)
		dir=${dir%/*}
	done
	echo "$mntopt"
}

add0() {
	# either call using add0 file.ldap or add0 -f ldap.filt file.ldap
	[ "$1" = "-f" ] && $2 "$3" && shift 2
	local cmd="slapadd -v -n 0 $(_arg -F $LDAP_CONFDIR) $(_arg -d $LDAP_LOGLEVEL) -l $1"
	inform 0 "Calling: $cmd"
	$cmd 2>&1
}

add() {
	# either call using add file.ldap or add -f ldap.filt file.ldap
	[ "$1" = "-f" ] && $2 "$3" && shift 2
	ldapmodify $(_isadd "$1") -Y EXTERNAL -H ldapi://$(_escurl $LDAP_IPCSOCK)/ -f "$1" 2>&1
}

search() { ldapsearch -Y EXTERNAL -H ldapi://$(_escurl $LDAP_IPCSOCK)/ $* ;}
modify() { ldapmodify -Y EXTERNAL -H ldapi://$(_escurl $LDAP_IPCSOCK)/ $* ;}
whoami() { ldapwhoami -Y EXTERNAL -H ldapi://$(_escurl $LDAP_IPCSOCK)/ $* ;}
delete() { ldapdelete -Y EXTERNAL -H ldapi://$(_escurl $LDAP_IPCSOCK)/ $* ;}

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
'/^olcArgsFile:/s/\s.*/'" $(_escdiv $LDAP_RUNDIR)\/slapd.args"'/;'\
'/^olcPidFile:/s/\s.*/'" $(_escdiv $LDAP_RUNDIR)\/slapd.pid"'/;'\
'/^olcDbDirectory/s/\s.*/'" $(_escdiv $LDAP_DATADIR)"'/;'\
'/^olcModulePath/s/\s.*/'" $(_escdiv $LDAP_MODULEDIR)"'/;'\
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

ldap_copyifro() {
	# make a rw copy if directory is mounted ro
	local voldir=${1-$LDAP_CONFVOL}
	local link=${2-$LDAP_CONFDIR}
	local tmproot=${3-$LDAP_RWCOPYDIR}
	if [ "$(_howmnt $voldir)" == "ro" ]; then
		if [ -n "$tmproot" ]; then
			local newdir=${tmproot}/${voldir##*/}
			inform 1 "$voldir is mouted read only, making rw copy here $newdir"
			cp -a $voldir $tmproot/
			rm -f $link
			ln -sf $newdir $link
		else
			inform 2 "$voldir is mouted read only"
		fi
	else
		inform 0 "$voldir is mouted read write"
	fi
}

ldap_fixatr() {
	# make sure all files are rw by user $LDAP_USER
	for dir in $@; do
		if [ -n "$(find $dir ! -user $LDAP_USER -print -exec chown -h $LDAP_USER: {} \;)" ]; then
			inform 1 "Changed owner to $LDAP_USER for some files in $dir"
		fi
		if [ -n "$(find -L $dir ! -user $LDAP_USER -print -exec chown $LDAP_USER: {} \;)" ]; then
			inform 1 "Changed owner to $LDAP_USER for some files in $dir"
		fi
		if [ -n "$(find -H $dir ! -perm -u+rw -print -exec chmod u+rw {} \;)" ]; then
			inform 1 "Changed permision to rw for some files in $dir"
		fi
	done
}

ldap_chk0() {
	# test configuration. if $LDAP_CONFDIR is empty, use seeds
	if [ -n "$(ls -A $LDAP_CONFDIR)" ]; then
		local test_str="$( { slaptest $(_arg -F $LDAP_CONFDIR); } 2>&1 )"
		if [ $? -eq 0 ]; then
			inform 0 "Valid configuration found in $LDAP_CONFDIR not touching it"
		else
			inform 2 "Invalid configuration found in $LDAP_CONFDIR:\n$test_str"
		fi
	else
		inform 1 "$LDAP_CONFDIR is empty, will use seeds"
		ldap_add0
		# ldap_add0 adds configuration files as user root, fixing this
		ldap_fixatr $LDAP_CONFDIR
	fi
}

ldap_chk1() {
	# test data. if no data found, use seeds
	if [ -n "$(pidof slapd)" ]; then
		local data_str="$(slapcat -a '(o=*)' | head -n1)"
		if [ -n "$data_str" ]; then
			inform 0 "Valid user data found: $data_str, so not touching it"
		else
			inform 1 "No user data found, will use seeds"
			ldap_add1
			# ldap_add1 adds configuration files as user root, fixing this
			ldap_fixatr $LDAP_DATADIR
		fi
	else
		inform 2 "slapd is not running, but normally it should."
	fi
}

ldap_add0() {
	# Apply configuration file(s) if config is missing
	local files="$(_findseed $LDAP_SEEDDIR0)"
	if [ -z "$files" ]; then
		inform 1 "Use default configuration, since no .ldif or .sh file found in $LDAP_SEEDDIR0" 
		mv $LDAP_SEEDDIRa/0* $LDAP_SEEDDIR0/.
		files="$(_findseed "$LDAP_SEEDDIR0")"
	fi
	for file in $files ; do
		case "$file" in
		*.sh)   inform 0 "Sourcing config file $file"; . "$file" ;;
		*.ldif) inform 0 "Applying config file $file"; add0 -f "ldif_config" "$file" ;;
		esac
	done
}

ldap_add1() {
	# Apply files if slapd is running and data is empty
	local files="$(_findseed "$LDAP_SEEDDIR1")"
	if [ -z "$files" ] && [ -z "$LDAP_DONTADDDCOBJECT" ]; then
		inform 1 "Use default database, since no .ldif or .sh file found in $LDAP_SEEDDIR1" 
		# no files found use default configuration
		mv $LDAP_SEEDDIRa/1* $LDAP_SEEDDIR1/.
		files="$(_findseed "$LDAP_SEEDDIR1")"
	fi
	for file in $files ; do
		case "$file" in
		*.sh)   inform 0 "Sourcing database file $file"; . "$file" ;;
		*.ldif) inform 0 "Applying database file $file"; add -f "ldif_users" "$file" ;;
		esac
	done
}

#
# change $LDAP_USER uid and gid
#

ldap_chid() {
	local uidgid=${1-$LDAP_UIDGID}
	# attempt to change $LDAP_USER uid and gid only if LDAP_UIDGID is not empty
	if [ -n "$LDAP_UIDGID" ]; then
		uid=${uidgid%:*}
		local _gid=${uidgid#*:}
		gid=${_gid-$uid}
		# do not change $LDAP_USER uid and gid if the uid is already set
		if [ ! $(getent passwd $uid > /dev/null) ]; then
			inform 0 "Will recreate $LDAP_USER user with $uid:$gid"
			deluser $LDAP_USER
			addgroup -g $gid -S $LDAP_USER
			adduser -u $uid -D -S -h /usr/lib/openldap -s /sbin/nologin -g 'OpenLDAP User' -G $LDAP_USER $LDAP_USER
		else
			inform 1 "NOT recreating $LDAP_USER user since it is $(id -u $LDAP_USER):$(id -g $LDAP_USER)"
		fi
	fi
}

#
# start things
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
	local cmd
	if [ -z "$(pidof slapd)" ]; then
		if [[ $# -eq 0 ]] ; then
			cmd="slapd $(_arg -d $LDAP_LOGLEVEL) -u $LDAP_USER -g $LDAP_USER -h \"ldap:/// ldapi://$(_escurl $LDAP_IPCSOCK)/\" $(_arg -F $LDAP_CONFDIR)"
		else
			cmd="$@"
		fi
		inform 0 "Starting ldap using: $cmd"
		exec $cmd
	else
		inform 1 "slapd already running"
	fi
}

start_cmd() {
	# try to start slapd if it not running
	# if user provided any argument assume they are the desired start command
	if [[ $# -eq 0 ]] ; then
		echo "slapd $(_arg -d $LDAP_LOGLEVEL) -u $LDAP_USER -g $LDAP_USER -h \"ldap:/// ldapi://$(_escurl $LDAP_IPCSOCK)/\" $(_arg -F $LDAP_CONFDIR)"
	else
		echo "$@"
	fi
}

#
# Define colors for output
#

define_formats

#
# Allow interactive mode
#

interactive $@

#
# Limiting the open file descriptors prevent excessive memory consumption by slapd
#

ulimit -n 8192

#
# Potentially change $LDAP_USER uid and gid
#

ldap_chid

#
# Make a rw copy of config and data directory if they are mounted ro
# Also check and fix file attributes within these directories
#

ldap_copyifro $LDAP_CONFVOL $LDAP_CONFDIR
ldap_copyifro $LDAP_DATAVOL $LDAP_DATADIR
ldap_fixatr $LDAP_CONFDIR ${LDAP_DATADIR%/*} $LDAP_RUNDIR $LDAP_CONFVOL $LDAP_DATAVOL

#
# Test configuration and use seed if empty
#

ldap_chk0

#
# Wait for slapd to start and then apply files in the background
#

( sleep 2 ; ldap_chk1 ) &

#
# Start slapd (if needed).
#

#start $@

if [ -z "$(pidof slapd)" ]; then
	inform 0 "Starting ldap using: $(start_cmd $@)"
#	exec $(start_cmd $@)
#	while true; do sleep 86400; done
	exec slapd $(_arg -d $LDAP_LOGLEVEL) -u $LDAP_USER -g $LDAP_USER -h "ldap:/// ldapi://$(_escurl $LDAP_IPCSOCK)/" $(_arg -F $LDAP_CONFDIR)
##	exec slapd -u $LDAP_USER -g $LDAP_USER -h "ldap:///" -F /etc/openldap/slapd.d
else
	inform 1 "slapd already running"
fi

