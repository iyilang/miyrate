# miyrate

A database migration tool for [iyi](https://iyi.dev): a port of
[micrate](https://github.com/amberframework/micrate) 0.15.1, written in iyi on
[iyi-db](https://github.com/iyilang/db). Like micrate, it is inspired by
[goose](https://bitbucket.org/liamstask/goose/).

A migration is a SQL file whose `-- +miyrate` directives (`Up`, `Down`,
`StatementBegin`, `StatementEnd`) mark what runs in each direction, and the
database records what was applied in the `miyrate_db_version` table.
micrate's `-- +micrate` directives and `micrate_db_version` table are not
read: rename them to move a micrate project over.

The `miyrate` executable migrates PostgreSQL (`postgres://`,
`postgresql://`, through [iyi-pg](https://github.com/iyilang/pg)) and SQLite
(`sqlite3:`, through [iyi-sqlite](https://github.com/iyilang/sqlite)). The
library also carries a MySQL dialect, for a program that registers a MySQL
driver itself; iyi has none yet.

## Building

iyi 0.18.0 or later.

```sh
iyi build -o bin/miyrate cmd/miyrate/main.iyi
```

SQLite needs its library at link time; see iyi-sqlite's requirements. On
Windows that is `sqlite3.lib` and `sqlite3.dll` in the directory named by
`IYI_LIBRARY_PATH`, and the build copies the DLL beside the executable.

## Command line

miyrate connects to the database named by the `DATABASE_URL` environment
variable and reads migrations from `db/migrations`.

```
$ miyrate help
Commands:
    create     Create the database (permissions required)
    drop       Drop the database (permissions required)
    up         Migrate the DB to the most recent version available
    down       Roll back the version by 1
    redo       Re-run the latest migration
    status     Dump the migration status for the current DB
    scaffold   Create the scaffolding for a new migration
    dbversion  Print the current version of the database
```

`miyrate scaffold add_users_table` writes
`db/migrations/20160524162446_add_users_table.sql`:

```sql
-- +miyrate Up
-- SQL in section 'Up' is executed when this migration is applied


-- +miyrate Down
-- SQL section 'Down' is executed when this migration is rolled back
```

Fill in both sections:

```sql
-- +miyrate Up
CREATE TABLE users(id INT PRIMARY KEY, email VARCHAR NOT NULL);

-- +miyrate Down
DROP TABLE users;
```

and run every pending migration with `miyrate up`:

```
$ miyrate up
Migrating db, current version: 0, target: 20160524162446
OK   20160524162446_add_users_table.sql

$ miyrate dbversion
20160524162446

$ miyrate status
Applied At                  Migration
=======================================
2016-05-24 16:31:07 UTC  -- 20160524162446_add_users_table.sql
Pending                  -- 20160524163425_add_address_to_users.sql
```

`down` rolls the latest migration back and `redo` rolls it back and applies
it again. Each migration runs in its own transaction.

A statement ends at a line ending in `;`. A statement with semicolons of its
own, such as a function body, goes between `StatementBegin` and
`StatementEnd`:

```sql
-- +miyrate Up
-- +miyrate StatementBegin
CREATE OR REPLACE FUNCTION histories_count()
returns bigint AS $$
DECLARE
  n bigint;
BEGIN
  SELECT count(*) INTO n FROM histories;
  RETURN n;
END;
$$
language plpgsql;
-- +miyrate StatementEnd
```

A migration that was never applied but is older than the database's current
version is not run: miyrate lists it and exits 1, since it may have been
written against an older schema. Rename it to a newer version to run it.

## Library

```sh
iyi get github.com/iyilang/miyrate --as miyrate
```

The modules, under that short name:

| module | what it holds |
|---|---|
| `miyrate` | `up`, `down`, `redo`, `dbversion`, `migration_status`, `create`, `migration_plan`, `extract_dbversion`, `migrations_dir`, `connection_url=` |
| `miyrate/miyrate/db` | `connection_url`, `connect`, and the version-table queries |
| `miyrate/miyrate/dialect` | `Dialect` and `Postgres`, `Mysql`, `Sqlite3` |
| `miyrate/miyrate/core` | `Migration`, `Direction` |
| `miyrate/miyrate/errors` | `MiyrateError`, `UnorderedMigrations`, `MigrationFailed` |
| `miyrate/miyrate/cli` | `run(args)`, `setup_log`, one function per command |

A runner of your own, with the drivers you want:

```iyi
module migrate

import pg
import miyrate/miyrate/cli
import miyrate/miyrate/db

Miyrate::Db.connection_url = "postgres://user:pswd@localhost/app"
Miyrate::Cli.setup_log
exit Miyrate::Cli.run(Program.args)
```

or, without the command line:

```iyi
import miyrate

Miyrate::Db.connect { |db| Miyrate.up(db) }
```

which answers `nil`, a `MiyrateError` or the driver's `DBError`.

## What is different from micrate

| micrate | miyrate | why |
|---|---|---|
| `-- +micrate Up`, table `micrate_db_version` | `-- +miyrate Up`, table `miyrate_db_version` | the tool's own name |
| raises `Exception`, `UnorderedMigrationsException` | answers `MiyrateError`, `UnorderedMigrations`, `MigrationFailed`, `DBError` | errors are values in iyi |
| a failed migration is logged and `micrate up` exits 0 | it is rolled back, reported, and `miyrate` exits 1 | the error is a value the CLI answers with |
| `migration_status` answers `Hash(Migration, Time?)` | `Array(Tuple(Migration, Time?))`, oldest first | the order `status` prints in, without hashing a class |
| `scaffold` versions with `Time.local` | with `Time.utc` | iyi's `std/time` has no local zone |
| `Micrate::DB.connection_url=`, `Migration.from_file(name)` | `Miyrate::Db.connection_url=`, `Migration.from_file(dir, name)` | a module path is a constant path; the migration module does not import the one that names the directory |
| `StatementBuilder` | `String::Builder` | the prelude's builder does it |

## Development

```sh
iyi test   # micrate's specs, ported
```
