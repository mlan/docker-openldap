
# Road map

## TLS

[Using TLS](https://openldap.org/doc/admin21/tls.html)

All servers are required to have valid certificates, whereas client  certificates are optional. Clients must have a valid certificate in  order to authenticate via SASL EXTERNAL.

The DN of a server certificate must use the CN attribute to name the server, and the `CN` must carry the server's fully qualified domain name. Additional alias names and wildcards may be present in the `subjectAltName` certificate extension.  The server must be configured with the CA certificates and also its own server certificate and private key.

The DN of a client certificate can be used directly as an authentication DN. At a minimum, the clients must be configured with the filename containing all of the Certificate Authority (CA) certificates it will trust. 

[Configure OpenLDAP with TLS certificates](https://www.golinuxcloud.com/configure-openldap-with-tls-certificates/)

```yml
dn: cn=config
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ssl/certs/mycacert.pem
-
add: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/ldap01_slapd_cert.pem
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/ldap01_slapd_key.pem
```

LDAP over TLS/SSL (ldaps://) is deprecated in favor of StartTLS. The latter refers to an existing LDAP session (listening on TCP port 389) becoming protected by TLS/SSL whereas LDAPS, like HTTPS, is a distinct encrypted-from-the-start protocol that operates over TCP port 636.

