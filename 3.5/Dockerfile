FROM 	alpine:3.5

LABEL 	maintainer=mlan

# Install OpenLDAP
RUN 	apk --no-cache --update add \
	openldap \
	openldap-clients

EXPOSE 	389


ENV 	LDAP_SEEDDIRa=/var/lib/openldap/seed/a \
	LDAP_SEEDDIR0=/var/lib/openldap/seed/0 \
	LDAP_SEEDDIR1=/var/lib/openldap/seed/1

RUN 	mkdir -p $LDAP_SEEDDIRa $LDAP_SEEDDIR0 $LDAP_SEEDDIR1 && \
	ln -s /entrypoint.sh /usr/local/bin/ldap

COPY 	entrypoint.sh .

COPY 	seed/a/* $LDAP_SEEDDIRa/

HEALTHCHECK CMD ldapwhoami -xH ldapi:// || exit 1

ENTRYPOINT ["/entrypoint.sh"]

