# ssl.mk
#
# SSL and TLS   make-functions
#

SSL_KEYF ?= priv_key.pem
SSL_CRTF ?= cert.pem
SSL_CRTD ?= 30
SSL_ACMF ?= acme.json
TST_SSLD ?= ssl
TST_ACMD ?= acme
TST_KEY  ?= $(TST_SSLD)/$(SSL_KEYF)
TST_CERT ?= $(TST_SSLD)/$(SSL_CRTF)
TST_ACME ?= $(TST_ACMD)/$(SSL_ACMF)


test-ssl-gen: $(TST_ACME)

%.p12: %.crt
	openssl pkcs12 -export -in $< -inkey $*.key -out $@ \
	-passout pass:$(LDAP_TEST_USERPW)

%.csr: %.key
	openssl req -new -key $< -out $@ \
	-subj "/O=$(MAIL_DOMAIN)/CN=$(LDAP_TEST_USER)/emailAddress=$(LDAP_TEST_USER)@$(MAIL_DOMAIN)"

%.smime.crt: %.smime.csr ssl/ca.crt
	openssl x509 -req -in $< -CA $(@D)/ca.crt -CAkey $(@D)/ca.key -out $@ \
	-setalias "Self Signed SMIME" -addtrust emailProtection \
	-addreject clientAuth -addreject serverAuth -trustout \
	-CAcreateserial

%.crt: %.key
	openssl req -x509 -batch -key $< -out $@ \
	-subj "/O=$(MAIL_DOMAIN)"

%.key: ssl
	openssl genrsa -out $@
	chmod a+r $@

ssl:
	mkdir -p $@
