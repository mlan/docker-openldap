ARG	DIST=alpine
ARG	REL=latest

FROM	$DIST:$REL
LABEL	maintainer=mlan

#
# Setup environment
#
ENV	DOCKER_BIN_DIR=/usr/local/bin \
	DOCKER_CONF_DIR=/etc/openldap \
	DOCKER_SLAPADD0_PATH="/ldif/0:/0.ldif:/etc/openldap/slapd.ldif" \
	DOCKER_SLAPADD1_PATH="/ldif/1:/1.ldif" \
	SYSLOG_LEVEL=5 \
	DOCKER_DB0_DIR=/etc/openldap/slapd.d \
	DOCKER_DB1_DIR=/var/lib/openldap/openldap-data \
	DOCKER_RUN_DIR=/var/run/openldap \
	DOCKER_IPC_DIR=/var/lib/openldap/run \
	DOCKER_MOD_DIR=/usr/lib/openldap \
	DOCKER_DB0_VOL=/srv/conf \
	DOCKER_DB1_VOL=/srv/data \
	DOCKER_RWCOPY_DIR=/tmp \
	DOCKER_RUNAS=root: \
	LDAPDEBUG=none \
	LDAPURI="ldapi:/// ldap:///"

#
# Install OpenLDAP and arrange directory structure
#
RUN	apk --no-cache --update add \
	openldap \
	openldap-backend-all \
	openldap-overlay-all \
	openldap-clients \
	openldap-passwd-sha2 \
	&& rm -rf \
	$DOCKER_DB0_DIR \
	$DOCKER_DB1_DIR \
	&& mkdir -p \
	$DOCKER_RUN_DIR \
	$DOCKER_DB0_VOL \
	$DOCKER_DB1_VOL \
	$DOCKER_IPC_DIR \
	&& chown -R $DOCKER_RUNAS \
	$DOCKER_DB0_VOL \
	$DOCKER_DB1_VOL \
	$DOCKER_RUN_DIR \
	&& ln -sf $DOCKER_DB0_VOL $DOCKER_DB0_DIR \
	&& ln -sf $DOCKER_DB1_VOL $DOCKER_DB1_DIR \
	&& chown -h $DOCKER_RUNAS $DOCKER_DB0_DIR $DOCKER_DB1_DIR

#
# Copy utility scripts including docker-entrypoint.sh to image
#
COPY	src/*/bin $DOCKER_BIN_DIR/
COPY	src/*/config $DOCKER_CONF_DIR/

HEALTHCHECK CMD whoami || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]

CMD	[]

EXPOSE	389
