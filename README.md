# usertag-for-mariadb

Stored routines library for MariaDB to create, read and manage tags for users.


## Motivation

MariaDB and MySQL do not support comments for certain types of objects. In particular,
MariaDB does not support comments for users and roles.

If in the future MariaDB will support comments for users and roles, it will probably
do it in a non-standard, dangerous way. While most other DBMSs support the [COMMENT ON
statement](https://sql-bits.com/comments-on-database-objects/),
MariaDB and MySQL support a COMMENT clause for some CREATE and ALTER statements.
Using ALTER statements to change a comment is potentially risky.

While MySQL has a [COMMENT clause](https://sql-bits.com/mariadb-mysql-comments-on-database-objects/)
for CREATE USER and ALTER USER, it also has an ATTRIBUTE clause which accepts a JSON document. This allows to insert semi-structured information. While this can potentially be
useful when attributes are handled by programs, for humans it is difficult to read
and modify manually JSON documents. This can easily lead to mistakes.

SQL Server supports [extended properties](https://sql-bits.com/sql-server-extended-properties-comments/). A set of stored procedures allows to associate
properties to any object, and easily read or manage them. This solution works
equally well for programs and humans.

This library is partly inspired by SQL Server properties. However, this solution
specifically applies to users and roles. This allows us to focus on what is needed
to associate complex information to users.

This library understands the idea of tag hierarchy. For example, to store multiple
contacts for users, it might be convenient to use tags like these:

 - `contact.email`
 - `contact.phone`
 - `contact.im.telegram`
 - `contact.im.skype`


## Requirements

usertag has been tested on:

 - MariaDB 10.11 LTS
 - MariaDB 10.6 LTS
 - Percona Server 8.0
 - MySQL 8.0

No plugins required.

No configuration requirements.


## Install

To install usertag, just run the `usertag.sql` file on the MariaDB server.

If you use the MariaDB CLI, you can do it in this way:

```
mariadb -c -A < usertag.sql
```

Or, with MariaDB versions older than 10.4:

```
mysql -c -A < usertag.sql
```


## Usage

Refer to the `tutorial.sql` file for a practical explanaiton by example.


## License and Copyright

Copyright: [Vettabase Ltd](https://vettabase.com), 2023

This work is licensed under a GNU General Public License, version 3.
