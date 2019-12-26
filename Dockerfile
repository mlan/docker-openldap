ARG	DIST=alpine
ARG	REL=latest

FROM	$DIST:$REL
LABEL	maintainer=mlan

# Install OpenLDAP
RUN	apk --no-cache --update add \
	openldap \
	openldap-backend-all \
	openldap-overlay-all \
	openldap-clients

ENV	LDAP_CONFDIR=/etc/openldap/slapd.d \
	LDAP_DATADIR=/var/lib/openldap/openldap-data \
	LDAP_RUNDIR=/var/run/openldap \
	LDAP_CONFVOL=/srv/conf \
	LDAP_DATAVOL=/srv/data \
	LDAP_SEEDDIRa=/var/lib/openldap/seed/a \
	LDAP_SEEDDIR0=/var/lib/openldap/seed/0 \
	LDAP_SEEDDIR1=/var/lib/openldap/seed/1 \
	LDAP_USER=ldap

RUN	rm -rf \
	$LDAP_CONFDIR \
	$LDAP_DATADIR && \
	mkdir -p \
	$LDAP_RUNDIR \
	$LDAP_CONFVOL \
	$LDAP_DATAVOL \
	$LDAP_SEEDDIRa \
	$LDAP_SEEDDIR0 \
	$LDAP_SEEDDIR1 && \
	chown -R $LDAP_USER: \
	$LDAP_CONFVOL \
	$LDAP_DATAVOL \
	$LDAP_RUNDIR \
	$LDAP_SEEDDIRa \
	$LDAP_SEEDDIR0 \
	$LDAP_SEEDDIR1 && \
	ln -sf $LDAP_CONFVOL $LDAP_CONFDIR && \
	ln -sf $LDAP_DATAVOL $LDAP_DATADIR && \
	chown -h $LDAP_USER: $LDAP_CONFDIR $LDAP_DATADIR && \
	ln -s /usr/local/bin/entrypoint.sh /usr/local/bin/ldap

COPY	entrypoint.sh /usr/local/bin/
COPY	seed/a/* $LDAP_SEEDDIRa/

RUN	chown -R $LDAP_USER: ${LDAP_SEEDDIRa%/*}

HEALTHCHECK CMD ldap whoami || exit 1

ENTRYPOINT ["entrypoint.sh"]

CMD	[]

EXPOSE	389
