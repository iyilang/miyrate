#!/usr/bin/env bash
# The executable end to end against the database DATABASE_URL names: a
# migration scaffolded, applied, redone and rolled back, with the version
# the database records checked after each step. $1 is the executable.
set -euo pipefail
miyrate=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
cd "$(mktemp -d)"

"$miyrate" scaffold add_users
file=$(ls db/migrations/*_add_users.sql)
version=$(basename "$file" | cut -d_ -f1)
printf -- '-- +miyrate Up\nCREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);\n\n-- +miyrate Down\nDROP TABLE users;\n' > "$file"

"$miyrate" up
test "$("$miyrate" dbversion)" = "$version"
"$miyrate" status | grep -v Pending | grep -q "_add_users.sql"

"$miyrate" redo
test "$("$miyrate" dbversion)" = "$version"

"$miyrate" down
test "$("$miyrate" dbversion)" = 0
"$miyrate" status | grep Pending | grep -q "_add_users.sql"
echo "smoke: ok"
