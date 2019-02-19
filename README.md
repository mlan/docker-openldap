
# OpenLDAP

The [OpenLDAP](https://www.openldap.org/) server is an open source implementation of the Lightweight Directory Access Protocol used to provide network authentication.

# The `mlan/openldap` repository

![docker build](https://img.shields.io/docker/build/mlan/openldap.svg) ![travis build](https://api.travis-ci.org/mlan/docker-openldap.svg?branch=master) ![image size](https://images.microbadger.com/badges/image/mlan/openldap.svg) ![docker stars](https://img.shields.io/docker/stars/mlan/openldap.svg) ![docker pulls](https://img.shields.io/docker/pulls/mlan/openldap.svg)

This (non official) Docker image contains an [Alpine Linux](https://alpinelinux.org/) based [OpenLDAP](https://www.openldap.org/) Server. The LDAP server is accessible on port 389 using the `ldap://` protocol as well as on a UNIX socket `ldapi://` within the container. The image is designed to have a small footprint, about 10 MB, and therefore packages needed for secure transfer are _not_ included in this image.

The OpenLDAP Server typically holds user login credentials, postal and e-mail addresses and similar pieces of information. This image help integrate an OpenLDAP server with other dockerized services.

## Features

Brief feature list follows below

- Initialization (seeding) using raw `slapcat` generated `.ldap` files
- Initialization (seeding) using environment variables
- Log directed to docker daemon with configurable level
- Accepts read only (RO) mounted database file systems
- Built in utility script `ldap` helping managing the databases
- Built in `.ldap` filters helping initiating and managing the databases
- Unix domain (IPC) socket support
- Configurable database paths, helping host volume management
- Configurable run-as-user `uid` and `gid`

## Tags

The breaking.feature.fix [semantic versioning](https://semver.org/) used. In addition to the three number version number you can use two or one number versions numbers, which refers to the latest version of the sub series. The tag `latest` references the build based on the latest commit to the repository.

To exemplify the usage of version tags, lets assume that the latest version is `1.2.3`. In this case, `1.2.3`, `1.2` and `1` all identify the same image.

# Usage

The OpenLDAP config and users databases are created when the container is run
for the first time. They are then either created to an empty state using
default or custom domain and root user credentials _or_ the databases can be
seeded with `.ldif` files made available to the container before its first run. 

Once the databases have been created, management of the OpenLDAP server is
possible both from outside the container using `ldap://` network access with
admin/root user credentials and/or the `ldapi://` socket from within the
container.

## Migrating an OpenLDAP server by cloning it

This use case relies on that config and users data are available in an preexisting OpenLDAP server.

#### Export source server config and users databases into `.ldif` files

```bash
sudo slapcat -n0 -o ldif-wrap=no -l seed/0/config.ldif
sudo slapcat -n1 -o ldif-wrap=no -l seed/1/users.ldif
```

#### Make `.ldif` files available to the container and run it

_either_ by mounting the host directory the files reside in
```bash
docker run -d --name openldap -p 389:389 \ 
  -v "$(pwd)"/seed:/var/lib/openldap/seed mlan/openldap
```
_or_ by first copying the host directory to the container
```bash
docker create --name openldap -p 389:389 mlan/openldap
docker cp seed openldap:/var/lib/openldap/
docker start openldap
```
Now you can [test that it works](#test-your-openldap-server)

Be aware that when the databases are seeded, the seeding `.ldif` files are __edited in place__ by LDIF filters, see [LDIF filters](#ldif-filters).

If you have your source OpenLDAP server running on the same host as you are running docker containers, you might need to change the port of you container to allow it to start.

## Start an OpenLDAP server instance using custom configuration

This will create an OpenLDAP server with an users database that only contain an domain component entry. The configuration is customized by passing [environment variables](#environment-variables) on the `docker run` command line.

#### Run container
```bash
docker run -d --name openldap -p 389:389 \
  -e LDAP_DOMAIN=example.com \
  -e LDAP_ROOTCN=admin \
  -e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
  mlan/openldap
```

#### Optional: Load user data
Generate, for example, by using a text editor, a LDIF file, with you user data. Bind to the OpenLDAP server using the `ldapadd` command and the rootdn user credentials. Here we illustrate this procedure by using a file, containing a users sample, that comes with this repository.
```bash
ldapadd -H ldap://:389 -x -D "cn=admin,dc=example,dc=com" -W -f seed/b/190-users.ldif
Enter LDAP Password:
```
Now you can [test that it works](#test-your-openldap-server)

## Start an OpenLDAP server instance using default configuration

This will create a OpenLDAP server with default configuration and an users database that only contain an domain component entry.
The default domain is `example.com`, the default rootdn is `cn=admin,dc=example,dc=com` and the default password is `secret`.

#### Run container
```bash
docker run -d -p 389:389 mlan/openldap
```
Now you can [test that it works](#test-your-openldap-server)

## Docker Compose example

An example of how to start an OpenLDAP server with already initiated (seeded) database using docker compose is given below:

```yaml
version: '3.7'
services:
  auth:
    image: mlan/openldap:1
    restart: unless-stopped
    networks:
      - backend
    environment:
      - LDAP_LOGLEVEL=parse
    volumes:
      - auth-conf:/srv/conf
      - auth-data:/srv/data
networks:
  backend:
volumes:
  auth-conf:
  auth-data:
```


## Test your OpenLDAP server

#### Anonymous authentication
```bash
ldapwhoami -H ldap://:389 -x

anonymous
```

#### Server "domain"
```bash
ldapsearch -H ldap://:389 -xLLL -s base namingContexts

dn:
namingContexts: dc=example,dc=com
```

#### Domain component
```bash
ldapsearch -H ldap://:389 -xLLL -b 'dc=example,dc=com' 'o=*'

dn: dc=example,dc=com
dc: example
objectClass: dcObject
objectClass: organization
o: example.com
```

#### User email address

```bash
ldapsearch -H ldap://:389 -xLLL -b "dc=example,dc=com" '(&(objectclass=person)(cn=Harm Coddington))' mail

dn: cn=Harm Coddington,ou=Janitorial,dc=example,dc=com
mail: CoddingH@ns-mail6.com
```

## Environment variables

When you start an mlan/openldap instance, you can adjust its configuration by passing one or more environment variables on the `docker run` command line. Once the instance has been run for the first time and the config and users databases has been created these variables will _not_ have any effect. Any existing databases will always be left untouched on container startup.

#### `LDAP_DOMAIN`

This is an optional variable, undefined by default, which when set allows defining/modifying the domain name in both the config and the users database. Example usage: `LDAP_DOMAIN=example.com`.
When you are using seeding files and the domain name defined therein is already the desired one you do not need to set this variable.

#### `LDAP_ROOTCN`

This is an optional variable, set to `admin` by default, which allows defining/modifying the root _distinguished name_ in the config database, using this _common name_ as a base. To have any effect both `LDAP_ROOTCN` and `LDAP_DOMAIN` need to be set to non-empty strings.
Example usage: `LDAP_DOMAIN=example.com` and `LDAP_ROOTCN=admin` will set/change the the root _distinguished name_ to `cn=admin,dc=example,dc=com`.
When you are using seeding files and the common name defined therein is already the desired one you do not need to set this variable.

#### `LDAP_ROOTPW`

This is an optional variable, undefined by default, which when set allows defining/modifying the root password. The password can be given in clear text or its hashed equivalent. Example: `LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3` (generated using `slappasswd -s secret`).
If no seeding files are provided, databases will be created with default configurations and unless `LDAP_ROOTPW` is set, the root password is `secret`.
When you are using seeding files and the root password defined therein is already the desired one you do not need to set this variable.

#### `LDAP_EMAILDOMAIN`

This is an optional variable, undefined by default, which when set allows modifying the email domain in the users database. Example usage: `LDAP_EMAILDOMAIN=example.com` will result in a user email address of `john.doe@example.com`.

#### `LDAP_DONTADDEXTERNAL`

This is an optional variable, undefined by default, which when set to a non-empty string the filters `ldif_unwrap` and `ldif_access` will not be applied.

#### `LDAP_DONTADDDCOBJECT`

This is an optional variable, undefined by default, which when set to a non-empty string prevents seeding of the users database with default domain component entry, `dcObject`, when the `LDAP_SEEDDIR1` is empty during seeding.
This leaves the users database completely empty, should this be desired.

#### `LDAP_LOGLEVEL`
This is an optional variable, set to `2048` by default. `LDAP_LOGLEVEL` can be 
set to either the log level number, its hex-value, or its log-name. For example 
setting `LDAP_LOGLEVEL` to `2048`, `0x800` or `parse` is equivalent. See 
[The slapd Configuration File](https://www.openldap.org/doc/admin24/slapdconfig.html)
for more details. Set to empty to allow the `olcLogLevel` database parameter to
take precedence. Example usage: `LDAP_LOGLEVEL=parse`

#### `LDAP_UIDGID`
This is an optional variable, undefined by default, which when set allows 
modifying the `uid` and `gid` of the ldap user running `slapd` inside the 
container. Example usage: `LDAP_UIDGID=120:127` will set the run-as-user, named `LDAP_USER`, user `uid` to
120 and its `gid` to 127. This can be useful when bind mounting volumes and 
you want a non root user be able to access the databases themselves.

#### `LDAP_USER`

This is an optional variable, set to `ldap` by default. This is the name of the run-as-user within the container. Example usage: `LDAP_USER=ldap`

#### `LDAP_CONFVOL`
This is an optional variable, set to `/srv/conf` by default, which when set can
be used to change the path to the config database within the container. Example usage: `LDAP_CONFVOL=/srv/conf`

#### `LDAP_DATAVOL`
This is an optional variable, set to `/srv/data` by default, which when set can
be used to change the path to the users database within the container. Example usage: `LDAP_DATAVOL=/srv/data`

#### `LDAP_CONFDIR`
This is an optional variable, set to `/etc/openldap/slapd.d` by default, which should correspond to the distributions expected path to the config database,
which here is replaced by the symbolic link pointing to it.

#### `LDAP_DATADIR`
This is an optional variable, set to `/var/lib/openldap/openldap-data` by 
default, which should correspond to the distributions expected path to the users database, which here is replaced by the symbolic link pointing to it.

#### `LDAP_RWCOPYDIR`
This is an optional variable, set to `/tmp` by default. This directory path is used
to determine the paths where copies `LDAP_CONFVOL` and `LDAP_DATAVOL` are placed if they are mounted read only. If you wish to disable this feature set
this variable to empty, that is `LDAP_RWCOPYDIR=`

#### `LDAP_MODULEDIR`
This is an optional variable, set to `/usr/lib/openldap` by default, which when
set can be used to change the path to the openldap modules.

#### `LDAP_RUNDIR`

This is an optional variable, set to `/var/run/openldap` by default, which when set can be used to change the path to the OpenLDAP `slapd.pid` and `slapd.args` files.

#### `LDAP_SEEDDIR0`

This is an optional variable, set to `/var/lib/openldap/seed/0` by default, which when set can be used to change the location where OpenLDAP finds files, in LDIF format, used during config database seeding.

#### `LDAP_SEEDDIR1`

This is an optional variable, set to `/var/lib/openldap/seed/1` by default, which when set can be used to change the location where OpenLDAP finds files, in LDIF format, used during users database seeding.

#### `LDAP_SEEDDIRa`

This is an optional variable, set to `/var/lib/openldap/seed/a` by default, which when set can be used to change the location where OpenLDAP finds default seeding files, which are used when no files can be found in the `LDAP_SEEDDIR0` or `LDAP_SEEDDIR1` directories, during database seeding.

## Where to store persistent data

By default docker will store the databases within the container. This has the 
drawback that the databases are deleted thogeter with the container if it is
deleted. The path to the configuration and data databases within the contatner
are `LDAP_CONFVOL=/srv/conf` and `LDAP_DATAVOL=/srv/data` respectively. 
Often it is useful to create a data directory on the host system 
(outside the container) and mount this to a directory visible from inside 
the container. This places the database files in a known location on the 
host system, and makes it easy for tools and applications on the host 
system to access the files.

To have persistent storage, you can start the OpenLDAP container like this:
```bash
docker run -d --name auth -p 389:389 \
  -v auth-conf:/srv/conf \
  -v auth-data:/srv/data \
  mlan/openldap
```

Alternatively you can start an OpenLDAP server with persistent data using docker-compose see the [docker compose example](#docker-compose-example).

# Implementation details

## Database locations
Typical paths are `/etc/openldap/slapd.d` and `/var/lib/openldap/openldap-data`.
Here these paths are symlinked to `/srv/conf` and `/srv/data` respectively. 
When the container is started and the directories `/srv/conf` and `/srv/data`
are mounted read only, they are copied to `/tmp/conf` and `/tmp/data` and the 
symlinks in `/etc/openldap/slapd.d` and `/var/lib/openldap/openldap-data` are 
chnaged accordingly.

## Database access

Many OpenLDAP servers are configured in a way allowing assess to the config and users databases using the EXTERNAL authentication method. In addition the users database can be assessed by authenticate using the rootdn user credentials, but often the config database cannot be accessed in this way.

#### Use the ldapi:// file socket and EXTERNAL authentication

Both config and users databases can normally be managed by connection to the LDAP server by using its file socket, ldapi:// and authenticate by EXTERNAL means by being the container root user (uid=0,gid=0).
```bash
docker cp seed/b/190-users.ldif openldap:/tmp/190-users.ldif
docker exec -it openldap ldapadd -Y EXTERNAL -H ldapi:/// -f /tmp/190-users.ldif
```

You can also use [the `ldap` utility](#the-ldap-utility) to access the LDAP server using its socket.

#### Use the ldap:// tcp port and simple authentication

The users database can normally be managed by connection to the LDAP server by using its tcp port, `ldap://` and use simple authentication by using the credentials of the rootdn user
```bash
ldapadd -H ldap:// -x -D "cn=admin,dc=example,dc=com" -W -f seed/b/190-users.ldif

Enter LDAP Password:
```
## Seeding

Files in [LDAP Data Interchange Format (LDIF)](http://www.openldap.org/software/man.cgi?query=ldif&apropos=0&sektion=0&manpath=OpenLDAP+2.4-Release&format=html) can be used to seed the config and/or users databases.

#### Seeding the config database

Files with names ending with either `.ldif` or `.sh` in the `LDAP_SEEDDIR0` directory will, in alphabetical order, be applied when the container is run for the first time when there is no config database.
The `*.ldif` files will be applied to the database by using `slapadd` and `*.sh` files will be sourced.

If no `.ldif` or `.sh` files can be found in the `LDAP_SEEDDIR0` directory during seeding the files matching `LDAP_SEEDDIRa/0*` will be moved here and applied.

Files in the `LDAP_SEEDDIR0` directory are ignored when a config database is present.

#### Seeding the users database

Files with names ending with either `.ldif` or `.sh` in the `LDAP_SEEDDIR1` directory will, in alphabetical order, be applied when the container is run for the first time when there is no users database.
The `*.ldif` files will be applied to the database by using `ldapmodify` and `*.sh` files will be sourced.

If no `.ldif` or `.sh` files can be found in the `LDAP_SEEDDIR1` directory during seeding the files matching `LDAP_SEEDDIRa/1*` will be moved here and applied.

Files in the `LDAP_SEEDDIR1` directory are ignored when a users database is present.

#### Default `.ldif` file directory

Default `.ldif` files are kept in the `LDAP_SEEDDIRa` directory. This directory is _not_ scanned at container start up, but if the `LDAP_SEEDDIR0` is empty, files with names matching `LDAP_SEEDDIRa/0*` will be moved to `LDAP_SEEDDIR0` and applied. Similarly if the `LDAP_SEEDDIR1` is empty, files with names matching `LDAP_SEEDDIRa/1*` will be moved to `LDAP_SEEDDIR1` and applied.

## LDIF filters

The LDIF filters are applied on `.ldif` files during seeding. Please be aware that the filters __edit the files in place__. The filters within the collection `ldif_config` are potentially applied to config `.ldif` files in the `LDAP_SEEDDIR0` directory during seeding. For the users `.ldif` files in the `LDAP_SEEDDIR1` directory the filter collection `ldap_users` is applied. Please be aware that the filters are implemented using the powerful `sed` command, and consequentially can be a bit fragile.

#### `ldif_intern`

Remove operational elements which are preventing LDIF files from being applied. Such operational elements are normally included when databases are exported by the command `slapcat`.

Since the users databases and their corresponding `.ldif` files can be large, this filter is only applied to an `.ldif` file if its first entry contains an operational element (`entryUUID`).

#### `ldif_paths`

Configures file paths used by the OpenLDAP server (`slapd`), simplifying reuse of config files.

#### `ldif_unwrap`

Unwraps lines in `.ldif` files, which `slapcat` inserts by default. (Wrapping can be avoided by using `slapcat -o ldif-wrap=no`).

#### `ldif_access`

This filter updates `olcAccess` elements in a way granting EXTERNAL access, if not already present, for all databases (frontend, config and backend). This allows entries to be added to the config and users databases during seeding without providing admin credentials.

This filter does not work for wrapped files, so the filer `ldif_unwrap` is applied first.

In cases where modifying access rights are not desired, the variable `LDAP_DONTADDEXTERNAL` can be set to a non-empty value preventing this filter from being applied.

#### `ldif_suffix`

This filter is used to apply the `LDAP_DOMAIN`, `LDAP_ROOTCN` and `LDAP_ROOTPW` variables to config files. The filter is not run if `LDAP_DOMAIN` and `LDAP_ROOTPW` are empty.

#### `ldif_domain`

This filter is used to apply the `LDAP_DOMAIN` variable to users files. The filter is not run if `LDAP_DOMAIN` is empty.

#### `ldif_email`

This filter is used to apply the `LDAP_EMAILDOMAIN` variable to users files. The filter is not run if `LDAP_EMAILDOMAIN` is empty.

#### `ldif_config`

This collection of filters are potentially applied to config `.ldif` files in the `LDAP_SEEDDIR0` directory during seeding. The filters applied are; `ldif_intern` `ldif_paths` `ldif_suffix` `ldif_unwrap` `ldif_access`.

#### `ldif_users`

This collection of filters are potentially applied to users `.ldif` files in the `LDAP_SEEDDIR1` directory during seeding. The filters applied are; `ldif_intern` `ldif_domain` `ldif_email`.

# The `ldap` utility ##

The command `ldap <cmd> <args>` can be issued on command line from within the container. This command is a wrapper of the docker `entrypoint.sh` shell script. Its purpose is to ease container management and debugging. Just typing `ldap` will provide a rudimentary help on how to use it.

To illustrate; the `ldap` utility can be used to reapply the LDIF filters, that was used during seeding, to new `.ldif` files.

```bash
docker cp seed/b openldap:/var/lib/openldap/seed/
docker exec -it openldap ldap add -f 'ldif_users' /var/lib/openldap/seed/b/191-user.ldif
```

# Docker Compose #
A [`docker-compose.yml`](docker-compose.yml) example is included in this repository.

# Issues Bugs Suggestions ##

Feel free to report any bugs or make suggestions [here](https://github.com/mlan/docker-openldap/issues)

# References ##

This work was inspired by [dweomer/dockerfiles-openldap](https://github.com/dweomer/dockerfiles-openldap)


