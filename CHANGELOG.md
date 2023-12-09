# 2.1.4

- [docker](src/docker) Now use alpine:3.19 (openldap 2.6.6).

# 2.1.3

- [docker](src/docker) Now use alpine:3.18 (openldap 2.6.5).

# 2.1.2

- [docker](src/docker) Now use alpine:3.18 (openldap 2.6.4).
- [github](.github/workflows/testimage.yml) Now use GitHub Actions to test image.
- [demo](demo/Makefile) Now depend on the docker-compose-plugin.

# 2.1.1

- [test](test/Makefile) Now use `bld_tag` so tests use correct image tag.
- [docker](src/docker) Now use alpine:3.16 (openldap 2.6.3).

# 2.1.0

- [docker](src/docker) Now use alpine:3.15 (openldap 2.6.0).
- [docker](Makefile) Now use functions in bld.mk.
- [docker](ROADMAP.md) Update badges.

# 2.0.2

- [docker](src/docker) Now use alpine:3.14 (openldap 2.4.58).
- [docker](ROADMAP.md) Use [travis-ci.com](https://travis-ci.com/).

# 2.0.1

- [docker](Dockerfile) Support additional modern password-hashing methods SHA256/512.

# 2.0.0

- [docker](Dockerfile) Now build using alpine:3.13 (openldap 2.4.56).
- [demo](demo) Updated demo.
- [test](test) Code refactoring.
- [docker](src/docker/bin/docker-entrypoint.sh) Code refactoring.
- [openldap](src/openldap/bin/openldap-common.sh) _BREAKING!_ New initialization procedure.
- [openldap](src/openldap/bin/openldap-common.sh) _BREAKING!_ Utility script `ldap` functionality abandoned, use ldap client tools directly instead.
- [openldap](src/openldap/bin/openldap-common.sh) Now default ldapi socket is used.
- [openldap](src/openldap/bin/openldap-common.sh) Revisited RUNAS code.
- [openldap](src/openldap/config/slapd.ldif) _BREAKING!_ Now no default domain component entry, `dcObject`, is created.
- [docker](README.md) Reworked documentation.
- [demo](demo) Now also demonstrate StartTLS and TLS/SSL.

# 1.1.0

- [repo](src) Put source code in the dir `src` and tests in `test`.

# 1.0.2

- Now build using alpine:3.11.
- Cosmetic changes.

# 1.0.1

- Now build using alpine:3.10.

# 1.0.0

- Log directed to docker daemon with configurable level.
- Accepts read only (RO) mounted database file systems.
- Unix domain (IPC) socket support.
- Configurable database paths, helping host volume management.
- Code refactoring.
