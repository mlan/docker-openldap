#!/bin/sh
#
# openldap-common.sh
#
# Defines common openldap functions. Source this file from other scripts.
#

#
# Config
#
DOCKER_SLAPD_CMD='slapd -d $LDAPDEBUG -h "$LDAPURI"'
DOCKER_FILTLDIF=/tmp/filterd.ldif
DOCKER_DB0_DIR=${DOCKER_DB0_DIR-/etc/openldap/slapd.d}
DOCKER_DB1_DIR=${DOCKER_DB1_DIR-/var/lib/openldap/openldap-data}
DOCKER_RUN_DIR=${DOCKER_RUN_DIR-/var/run/openldap}
DOCKER_MOD_DIR=${DOCKER_MOD_DIR-/usr/lib/openldap}
DOCKER_DB0_VOL=${DOCKER_DB0_VOL-/srv/conf}
DOCKER_DB1_VOL=${DOCKER_DB1_VOL-/srv/data}
DOCKER_RWCOPY_DIR=${DOCKER_RWCOPY_DIR-/tmp}
DOCKER_RUNAS=${LDAPRUNAS-$DOCKER_RUNAS}  # TODO confusing please fix

#
# Helpers
#

oc_find_ldif() { find "$@" -type f -iname "*.ldif" 2> /dev/null ;}
#oc_isfor_slapadd() { [ -n "$(sed '1,1000!d;{/dn: .*cn=config/!d;N;/changetype/d}' $1)" ] ;}
oc_escdiv() { echo $1 | sed 's|/|\\\/|g' ;}
#oc_escurl() { echo $1 | sed 's|/|%2F|g' ;}
oc_dc() { echo "$1" | sed 's/\./,dc=/g' ;}
oc_dn() { echo "cn=$1,$2" ;}
#oc_isadd() { [ -z "$(sed '1,1000!d;/changetype: /!d;q' $1)" ] && echo "-a" ;}

#
#
#
# Make a RW copy of config and data directory if they are mounted RO.
#
openldap_copy_if_ro() {
	oc_copyifro $DOCKER_DB0_VOL $DOCKER_DB0_DIR
	oc_copyifro $DOCKER_DB1_VOL $DOCKER_DB1_DIR
	oc_fixatr $DOCKER_DB0_DIR ${DOCKER_DB1_DIR%/*} $DOCKER_RUN_DIR $DOCKER_DB0_VOL $DOCKER_DB1_VOL
}

#
# make a rw copy if directory is mounted ro
#
oc_copyifro() {
	local voldir=${1-$DOCKER_DB0_VOL}
	local link=${2-$DOCKER_DB0_DIR}
	local tmproot=${3-$DOCKER_RWCOPY_DIR}
	if [ "$(oc_howmnt $voldir)" == "ro" ]; then
		if [ -n "$tmproot" ]; then
			local newdir=${tmproot}/${voldir##*/}
			dc_log 5 "$voldir is mounted read only, making rw copy here $newdir"
			cp -a $voldir $tmproot/
			rm -f $link
			ln -sf $newdir $link
		else
			dc_log 3 "$voldir is mounted read only"
		fi
	else
		dc_log 6 "$voldir is mounted read write"
	fi
}

#
# search if arg is mentioned in /proc/mounts and return its mount options
# if arg is not mentioned try its parent directory
# make sure arg is absolute path
#
oc_howmnt() {
	local dir=/${1#/}
	local mntopt=
	while [ -n "$dir" -a -z "$mntopt" ]; do
		mntopt=$(sed -nr 's/[^ ]+ '"$(oc_escdiv $dir)"' [^ ]+ ([^,]+).*/\1/p' /proc/mounts)
		dir=${dir%/*}
	done
	echo "$mntopt"
}

#
# make sure all files are rw by user $DOCKER_RUNAS
#
oc_fixatr() {
	local uid=${DOCKER_RUNAS%:*}
	for dir in $@; do
		if [ -n "$(find $dir ! -user $uid -print -exec chown -h $DOCKER_RUNAS {} \;)" ]; then
			dc_log 5 "Changed owner to $uid for some files in $dir"
		fi
		if [ -n "$(find -L $dir ! -user $uid -print -exec chown $DOCKER_RUNAS {} \;)" ]; then
			dc_log 5 "Changed owner to $uid for some files in $dir"
		fi
		if [ -n "$(find -H $dir ! -perm -u+rw -print -exec chmod u+rw {} \;)" ]; then
			dc_log 5 "Changed permision to rw for some files in $dir"
		fi
	done
}

#
#
#
# Try to create databases if they are missing.
#
openldap_create_db() {
	for dbnum in 0 1; do
		if [ -n "$(slapcat -n $dbnum)" ]; then
			dc_log 5 "Database $dbnum present, so not touching it"
		else
			dc_log 5 "Database $dbnum not found, looking for backup files"
			oc_slapadd_dbnum $dbnum
		fi
	done
	oc_fixatr $DOCKER_DB0_DIR ${DOCKER_DB1_DIR%/*}
}

#
# Look for ldif backup files to apply to databases
#
oc_slapadd_dbnum() {
	for dbnum in $@; do
		dc_log 7 "Now search for files to add to dbnum $dbnum"
		for dir in $(case $dbnum in 0) echo $DOCKER_SLAPADD0_PATH;; 1) echo $DOCKER_SLAPADD1_PATH;; esac | tr : " "); do
			dc_log 7 "Now search for files to add in dir $dir"
			for file in $(oc_find_ldif $dir); do
				dc_log 5 "Adding $file to dbnum $dbnum"
				oc_cat $file > $DOCKER_FILTLDIF
				oc_slapadd_filter $DOCKER_FILTLDIF
				slapadd -F $DOCKER_DB0_DIR -n $dbnum < $DOCKER_FILTLDIF
				rm -f $DOCKER_FILTLDIF
			done
			[ -n "$file" ] && break
		done
	done
}

#
# Decompress files if needed.
#
oc_cat() {
	if zcat -t "$1" 2> /dev/null; then
		zcat "$1"
	else
		cat "$1"
	fi
}

#
# pass ldif file through filters to update parameters
#
oc_slapadd_filter() {
	ldif_paths  "$1" &&
	ldif_root   "$1"
}

#
#
#
# Parse command arguments
#
openldap_envs_from_args() {
	local var=
	while [[ "$#" -ge 1 ]]; do
		case "$1" in
		--base|--root-cn|--root-pw|--runas|--debug)
			eval "export $(oc_arg_to_var $1)=$2"
			shift 2
			;;
		--*)
			shift 1
			;;
		*)
			exec "$@"
			;;
		esac
	done
}

oc_arg_to_var() { echo "$@" | sed 's/--/ldap/;s/-/_/g' | tr [a-z] [A-Z] ;}

#
#
#
# Run command
# TODO needs cleanup
#
openldap_entrypoint_cmd() {
	# try to start slapd if it not running
	# if user provided any argument assume they are the desired start command
#	LDAP_LOGLEVEL=${LDAP_LOGLEVEL-$DOCKER_LDAP_LOGLEVEL}
	oc_runas
	eval "set -- ${DOCKER_CMD-$DOCKER_SLAPD_CMD}"
	if [ -z "$(pidof $1)" ]; then
		dc_log 7 "DOCKER_CMD=$DOCKER_CMD"
		dc_log 5 "exec $@"
		exec "$@"
	else
		dc_log 5 "$1 already running"
	fi
}

#
# change $DOCKER_RUNAS uid and gid if LDAPRUNAS defined.
#
oc_runas() {
	local runas=${1-$LDAPRUNAS}
	if [ -n "$runas" ]; then
		local uid=${runas%:*}
		local _gid=${runas#*:}
		local gid=${_gid:-$uid}
		local passwd="$(getent passwd $uid)"
		local group="$(getent group $gid)"
		if [ -z $passwd ]; then
			dc_log 7 "Recreating ldap user with $uid:$gid"
			deluser ldap
			if [ -z $group ]; then
				addgroup -g $gid -S ldap
				group=ldap
			else
				group=${group%%:*}
			fi
			adduser -u $uid -D -S -h /usr/lib/openldap -s /sbin/nologin \
			-g 'OpenLDAP User' -G $group ldap
		fi
		export DOCKER_SLAPD_CMD="$DOCKER_SLAPD_CMD -u $uid -g $gid"
		dc_log 6 "Got LDAPRUNAS=$runas so will run using $uid:$gid"
	fi
}

#
#
#
# LDIF filters
#

#
# Update container specific paths
#
ldif_paths() {
	sed -i \
'/^olcArgsFile:/s/\s.*/'" $(oc_escdiv $DOCKER_RUN_DIR)\/slapd.args"'/;'\
'/^olcPidFile:/s/\s.*/'" $(oc_escdiv $DOCKER_RUN_DIR)\/slapd.pid"'/;'\
'/^olcDbDirectory/s/\s.*/'" $(oc_escdiv $DOCKER_DB1_DIR)"'/;'\
'/^olcModulePath/s/\s.*/'" $(oc_escdiv $DOCKER_MOD_DIR)"'/;'\
'/^olcModuleLoad/s/\.la$//' "$1"
}

#
# Update database suffix, root DN and passwd
#
ldif_root() {
	if [ -n "$LDAPBASE" ]; then
		dc_log 7 "olcSuffix: $LDAPBASE"
		sed -i "/^olcSuffix:/s/\s.*/ $LDAPBASE/" $1
		if [ -n "$LDAPROOT_CN" ]; then
			local rootdn="$(oc_dn $LDAPROOT_CN $LDAPBASE)"
			dc_log 7 "olcRootDN: $rootdn"
			sed -i "/^olcRootDN:/s/\s.*/ $rootdn/" $1
		fi
		if [ -n "$LDAPROOT_PW" ]; then
			dc_log 7 "olcRootPW: $LDAPROOT_PW"
			sed -i "/^olcRootPW:/s/\s.*/ $LDAPROOT_PW/" $1
		fi
	fi
}

#
# LDIF filters
# Not used
#
ldif_unwrap() { sed -i ':a;N;$!ba;s/\n //g' "$1" ;}
ldif_intern() {
	# Remove operational entries preventing file from being applied
	# since data files can be large, only process file
	# if first entry contains an operational entry
	sed -i \
'/^structuralObjectClass/d;'\
'/^entryUUID/d;'\
'/^entryCSN/d;'\
'/^creatorsName/d;'\
'/^createTimestamp/d;'\
'/^modifiersName/d;'\
'/^modifyTimestamp/d' $1
}
ldif_access() {
	# insert local root manage access if some database is missing it
	if [ -n "$LDAP_MANAGE" ]; then
		local manage="by $LDAP_MANAGE manage"
		dc_log 7 '/^olcAccess: .*to \* by .*/bX ; p ; d; :X /external/!s/(.*to \* )(by .*)/\1'"$manage"' \2/'
		sed -i -r '/^olcAccess: .*to \* by .*/bX ; p ; d; :X /external/!s/(.*to \* )(by .*)/\1'"$manage"' \2/' "$1"
	fi
}
ldif_suffix() {
	local domain=${2-$LDAP_DOMAIN}
	if [ ! -z "$domain" ]; then
		sed -i -r \
's/([a-z]+: )[ ]*(uid=[^,]*,)?[ ]*(cn=[^,]*,)?[ ]*(ou=[^,]*,)?[ ]*(dc=.*)/\1\2\3\4'"dc=$(oc_dc $domain)"'/;'\
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
