
# What is the mlan/openldap image?
----
openldap in a alpine based docker container.
Normally modifying the ldap configuration is only done when
logged in to the host running the openldap service and, here, 
that means it needs to be done from within the container.
To simplify management in our case, we use an approach where management 
is  performed by copying ldif files to the container before it is started, and 
then once the container starts it will apply these files to the ldap database and configuration.

# How to use the mlan/openldap image  
----
## Start a Openldap server instance by cloning another working Openldap server
----
This use case relies on a preexisting working openldap service.

#### Dump source database and configuration

```bash
$ sudo slapcat -n0 -o ldif-wrap=no -l seed/0/conf.ldif  
$ sudo slapcat -n1 -o ldif-wrap=no -l seed/1/data.ldif
```

#### Run container and make configuration files available

_either_ by mounting the host directory they reside in
```bash
$ docker run -d --name openldap -p 389:389 -v "$(pwd)"/seed:/var/lib/openldap/seed mlan/openldap
```
_or_ by first copying the host directory to the container
```bash
$ docker create --name openldap -p 389:389 mlan/openldap
$ docker cp ./seed openldap:/var/lib/openldap/seed
$ docker start openldap
```
Now you can [test that it works](#test-your-openldap-server)

## Start a Openldap server instance using custom configuration
----
This will create a ldap server with an initially empty database.

#### Run container
```bash
$ docker run -d --name openldap -p 389:389 \
  -e LDAP_DOMAIN=example.com \
  -e LDAP_ROOTCN=admin \
  -e LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3 \
  mlan/openldap
```

#### Optional; load data
By some means communicate with ldap server to load user data. For example generate users.ldif and load with ldapadd:
```bash
$ ldapadd -H ldap://:389 -x -D "cn=admin,dc=example,dc=com" -f users.ldif
```
Now you can [test that it works](#test-your-openldap-server)

## Start a Openldap server instance using default configuration
----
This will create a ldap server with default configuration and empty database.

#### Run container
```bash
$ docker run -d -p 389:389 mlan/openldap
```
Now you can [test that it works](#test-your-openldap-server)


## Test your Openldap server
----
#### Anonymous authentication
  ```bash
  $ ldapwhoami -H ldap://:389 -x  
  > anonymous
  ```
#### LDAP server domain
  ```bash
  $ ldapsearch -H ldap://:389 -xLLL -s base namingContexts  
  > dn:
  > namingContexts: dc=example,dc=com
  ```
#### LDAP database contents
  ```bash
  $ ldapsearch -H ldap://:389 -xLLL -b dc=example,dc=com  
  > dn: dc=example,dc=com
  > objectClass: top
  > objectClass: dcObject
  > objectClass: organization
  > o: example.com
  > dc: example
  > ...

  ```

## Environment variables
----
When you start the mlan/openldap image, you can adjust the configuration of the openldap instance by passing one or more environment variables on the `docker run` command line. Do note that none of the variables below will have any effect if you start the container with a data directory that already contains a database: any pre-existing database will always be left untouched on container startup.

#### `LDAP_DOMAIN`

When this variable is set, without any pre-existing database, the database will be generated with this domain name. Example: `LDAP_DOMAIN=example.com`.
Please note that if configuration files are provided at container creation, normally the domain defined is already the desired one and this variable need not be set.

#### `LDAP_ROOTCN`

When `LDAP_DOMAIN` is set, without any pre-existing database, the database will be generated with a root distinguished name using this common name as a base. Example: `LDAP_DOMAIN=example.com` and `LDAP_ROOTCN=admin` results in `cn=admin,dc=example,dc=com`. If not provided `LDAP_ROOTCN` defaults to `admin`.
Please note that if configuration files are provided at container creation, normally the root common name defined is already the desired one and this variable need not be set.

#### `LDAP_ROOTPW`

When this variable is set, without any pre-existing database, the database will be generated with this root password. The password can be given in clear text or its hashed equivalent. Example: `LDAP_ROOTPW={SSHA}KirjzsjgMvjqBWNNof7ujKhwAZBfXmw3` (generated using `slappasswd -s secret`).
Please note that if configuration files are provided at container creation, normally the root password defined is already the desired one and this variable need not be set. If no configuration files are provided, database with default configuration will be generated and unless `LDAP_ROOTPW` is set the root password will be set to `secret`.

#### `LDAP_CONFDIR`

In most use cases this variable is not needed. If not provided it defaults to `/etc/openldap/slapd.d`. It can be used to change the location of the LDAP config database.

#### `LDAP_DATADIR`

In most use cases this variable is not needed. If not provided it defaults to `/var/lib/openldap/openldap-data`. It can be used to change the location of the LDAP users database.

#### `LDAP_MODULEDIR`

In almost most all use cases this variable is not needed. If not provided it defaults to `/usr/lib/openldap`. It defines path to the openldap modules and is distribution specific. 

#### `LDAP_RUNDIR`

In almost most all use cases this variable is not needed. If not provided it defauts to `/var/run/openldap`. It defines path to the openldap slapd.pid and slapd.args files. 

#### `LDAP_SEEDDIR0`

In most use cases this variable is not needed. If not provided it defauts to `/var/lib/openldap/seed/0`. It can be used to change the location of where openldap finds config files, in ldif format, during database seeding.

#### `LDAP_SEEDDIR1`

In most use cases this variable is not needed. If not provided it defauts to `/var/lib/openldap/seed/1`. It can be used to change the location of where openldap finds data files, in ldif format, during database seeding.

#### `LDAP_SEEDDIRa`

In most use cases this variable is not needed. If not provided it defauts to `/var/lib/openldap/seed/a`. It can be used to change the location of where openldap finds the default config file if no files can be found in `LDAP_SEEDDIR0`, during database seeding.

#### `LDAP_DONTADDEXTERNAL`

If this variable is set to a non-empty string the filters `ldif_unwrap` and `ldif_access` will not be used. This variable is not defined by default.

## Where to store data
----
By default docker will store the databases within the container. Often it is useful to create a data directory on the host system (outside the container) and mount this to a directory visible from inside the container. This places the database files in a known location on the host system, and makes it easy for tools and applications on the host system to access the files.

Start the openldap container like this
```bash
$ docker run -d --name openldap -p 389:389 \
  -v ./seed:/var/lib/openldap/seed \
  -v ldap-conf:/etc/openldap/slapd.d \
  -v ldap-data:/var/lib/openldap/openldap-data \
  mlan/openldap
```

# Implementation details
----
## Database access
----
When considering the common access scheme use for most LDAP servers, the user database and either be managed the same way that the configuration is, that is by using the EXTERNAL authentication method or one can authenticate using the rootdn user:

#### Use the ldapi:// file socket and EXTERNAL authentication

Both user data and configuration can normally be managed by connection to the LDAP server by using its file socket, ldapi:// and authenticate by EXTERNAL means by being the container root user (uid=0,gid=0).
```bash
$ docker cp data.ldif openldap:/tmp/data.ldif  
$ docker exec -it openldap ldapadd -Y EXTERNAL -H ldapi:/// -f /tmp/data.ldif
```

#### Use the ldap:// tcp port and simple authentication

The user data can normally be managed by connection to the LDAP server by using its tcp port, ldap:// and use simple authentication by using the credentials of the rootdn user 
```bash
$ ldapadd -H ldap:// -x -D "cn=admin,dc=example,dc=com" -f data.ldif  
> Enter LDAP Password:
```
## Seeding
----

#### Config database

Files with names ending with either .ldif or .sh in the `LDAP_SEEDDIR0` directory will be applied when the container is run for the first time when there is no config database.
The *.ldif files will be applied to the database by using slapadd and *.sh files will be sourced.

Files in the `LDAP_SEEDDIR0` directory are ignored when a config database is present.

If no .ldif or .sh files can be found in the `LDAP_SEEDDIR0` directory during seeding the file `LDAP_SEEDDIRa/slapd.ldif` will be copied here and applied.

#### Directory Information Tree (DIT) database

Files with names ending with either .ldif or .sh in the `LDAP_SEEDDIR1` directory  will be applied when the container is run for the first time when there is no DIT database.
The *.ldif files will be applied to the database by either using ldapadd or ldapmodify, whichever is appropriate, and *.sh files will be sourced.

Files in the `LDAP_SEEDDIR1` directory are ignored when a DIT database is present.

## LDIF filters
----

The ldif filters are applied on ldif files during seeding. The filters does edit the files in place. All filters described below are potentially applied to config .ldif files in the `LDAP_SEEDDIR0` directory using seeding. For DIT .ldif files in the `LDAP_SEEDDIR1` directory only the `ldif_intern` filter is applied.

#### `ldif_intern`

Remove operational elements preventing ldif files from being applied. Since data files can be large, the ldif file is only processed if the first entry contains an operational element (`entryUUID`).

#### `ldif_paths`

Configures file paths used by the ldap server (`slapd`), simplifying reuse of configuration files.
 
#### `ldif_unwrap`

Unwraps lines in ldif files, which slapcat inserts by default. (Wrapping can be avoided by using `slapcat -o ldif-wrap=no`).

#### `ldif_access`

This filter updates `olcAccess` elements to granting EXTERNAL access, if not already present, for all databases (frontend, config and backend). This allows entries to be added to the directory information tree during seeding without providing admin credentials.

This filter does not work for wrapped files, so the filer `ldif_unwrap` is applied first.

In cases where modifying access rights are not desired, the variable `LDAP_DONTADDEXTERNAL` can be set to a non-empty value preventing this filter to be applied.

#### `ldif_domain`

This filter is used to apply the `LDAP_DOMAIN`, `LDAP_ROOTCN` and `LDAP_ROOTPW` variables. The filter is not run if `LDAP_DOMAIN` and `LDAP_ROOTPW` are empty.

## The `ldap` utility
----

The command `ldap <cmd> <args>` can be issued on command line from within the container. This command is a wrapper of the docker entrypoint shell script. Its purpose is to ease container management and debugging. Just typing `ldap` will provide a rudimentary help on how to use it.

# References

This work was inspired by [dweomer/dockerfiles-openldap](https://github.com/dweomer/dockerfiles-openldap)


