#### Directory Information Tree (DIT) database

Files with names ending with either .ldif or .sh in the `LDAP_SEEDDIR1` directory  will be applied when the container is run for the first time when there is no DIT database.
The *.ldif files will be applied to the database by either using ldapadd or ldapmodify, whichever is appropriate, and *.sh files will be sourced.

Files in the `LDAP_SEEDDIR1` directory are ignored when a DIT database is present.
