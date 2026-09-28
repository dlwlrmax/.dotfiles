---
name: sql-langmaster
description: Connect to MySQL local and prod via discrete DB_* vars and wrappers. Reads anywhere, writes local only. Prod is strictly read-only. Enforces env separation and prod safety.
---

# DB Connect

## Overview

MySQL only. No `DATABASE_URL` — discrete vars for maintainability.

Local:
- `DB_HOST=192.168.3.213`
- `DB_PORT=3306`
- `DB_USERNAME=dev`
- Prod: `DB_HOST=192.168.3.213`, `DB_PORT=3307` — same host, different port/user. Never guess.

Rule: reads allowed both envs. Writes allowed local only. Prod = READ ONLY, no exceptions.

## Env Resolution

1. Central source of truth: `~/.dotfiles/.env` (local `DB_*` + prod `PROD_DB_*`), beside `.env.local` / `.env.prod`. Always read central first — ignore project `./.env` unless user explicitly requests it.
2. Expected vars:
   ```bash
   DB_CONNECTION=mysql
   DB_HOST=192.168.3.213      # local; prod same host, port 3307
   DB_PORT=3306               # prod 3307
   DB_DATABASE=erp_hbr        # per-project, never shared
   DB_USERNAME=dev            # prod user ba
   DB_PASSWORD=               # empty in repo, real value in central ~/.dotfiles/.env only
   ```
3. Rules:
   - `.env.local` = local. `.env.prod` = prod, never in repo, never copy to local.
   - Track `.env.example` only. Gitignore `.env`, `.env.*` (except example).
   - One connection per task. Announce `HOST/DB/ENV` before exec.
   - Mask secrets: `USER:***@HOST:PORT/DB`. Never print full PASS, never commit.
   - Reuse across projects: reuse HOST, never reuse same DB/user. Create per-project DB + user.

## Workflow

### Step 1: Setup wrappers (once per machine)

`mysql` here is a container shim: no `mysql_config_editor`, ignores `~/.my.cnf`. Use wrappers in `~/.local/bin` (on `PATH`, work from any project dir, creds from central `~/.dotfiles/.env`, never in history):

```bash
# mysql-local — local, read + write
mysql-local -e "SELECT 1 AS ok; SHOW DATABASES;"
mysql-local erp_hbr -e "SELECT id, name FROM actions LIMIT 20;"

# mysql-prod — prod, READ ONLY (wrapper argv deny-list, best-effort; real enforcement = SELECT-only GRANTs for `ba`)
mysql-prod -e "SHOW DATABASES;"
mysql-prod erp_hbr -e "SELECT id, name FROM actions LIMIT 20;"
# wide rows: end query with \G instead of ;  →  -e "SELECT * FROM actions LIMIT 1\G"
```

Recreate wrappers if lost (passwords come from central `.env`, never typed):

```bash
# mysql-local
printf '#!/bin/bash\nset -a; source ~/.dotfiles/.env; set +a\nexec env MYSQL_PWD="$DB_PASSWORD" mysql --default-character-set=utf8mb4 --table -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" "$@"\n' > ~/.local/bin/mysql-local
# mysql-prod: same shape with PROD_DB_* vars + write-keyword guard
printf '#!/bin/bash\nif printf "%%s" "$*" | grep -Eiq "\\b(insert|update|delete|replace|alter|create|drop|truncate|grant|revoke|load|outfile|dumpfile)\\b"; then echo "REFUSED: prod is read-only (SELECT/SHOW/DESC/EXPLAIN only)" >&2; exit 1; fi\nset -a; source ~/.dotfiles/.env; set +a\nexec env MYSQL_PWD="$PROD_DB_PASSWORD" mysql --default-character-set=utf8mb4 --table -h "$PROD_DB_HOST" -P "$PROD_DB_PORT" -u "$PROD_DB_USERNAME" "$@"\n' > ~/.local/bin/mysql-prod
chmod 700 ~/.local/bin/mysql-local ~/.local/bin/mysql-prod
```

### Step 2: Read (both envs)

Use read-only tool first. No shell needed for SELECT/SHOW/DESC/EXPLAIN/WITH.

```
mysql.read_query(sql="SHOW TABLES")
mysql.read_query(sql="DESC users")
mysql.read_query(sql="SELECT * FROM users LIMIT 20")
```

Limits: `LIMIT 20` default. No `SELECT *` on prod without `LIMIT`.

Shell fallback:

```bash
mysql-local -e "SHOW TABLES FROM erp_hbr;"
mysql-local erp_hbr -e "SELECT id, name FROM actions LIMIT 20;"
mysql-prod -e "SHOW TABLES FROM erp_hbr;"
mysql-prod erp_hbr -e "SELECT id, name FROM actions LIMIT 20;"
```

### Step 3: Write (LOCAL ONLY)

Prod writes forbidden. Refuse `INSERT/UPDATE/DELETE/ALTER/CREATE/DROP/TRUNCATE` on prod, even with user approval. Offer read-only alternative instead. Never pipe stdin or redirect files into mysql-prod (guard inspects argv only). `ba` holds SELECT-only GRANTs — that is the real enforcement.

Local writes only:

1. SELECT first: `SELECT COUNT(*) ... WHERE ...` to prove scope.
2. Confirm: state env (`HOST/DB`), SQL, row count. Wait for explicit yes.
3. Require `WHERE` on `UPDATE/DELETE`. No bare `DROP DATABASE`, no `TRUNCATE` without backup.
4. Verify after with `SELECT`. Delete temp files containing PASS.

### Step 4: Verify + Close

- Re-run `SELECT` to confirm change (local) or result set (prod).
- Report: env, host, affected rows or row count, verify query.
- Never leave credentials in output files.

## Local vs Prod Checklist

- [ ] Which file vars came from (`.env.local` vs `.env.prod`)?
- [ ] `HOST/DB/ENV` announced?
- [ ] `LIMIT` on reads?
- [ ] Prod: read-only query only, no write attempted?
- [ ] Local write: `WHERE` + approval?
- [ ] Secrets masked?

## Troubleshooting

- `2003 (111)`: wrong host/port, firewall, VPN off. Local `192.168.3.213:3306`, prod `192.168.3.213:3307`.
- `Access denied`: wrong PASS, user host grant missing, test `SELECT USER(),DATABASE()`.
- `Unknown database`: check `DB_DATABASE`, `SHOW DATABASES;` first.
- Laravel: use `DB_*` vars, no `DATABASE_URL` override.
- Font `?`/mojibake: client charset mismatch. Wrappers already pass `--default-character-set=utf8mb4`. If raw `mysql` used, add same flag.
- Copy `.env.prod` → central `.env`: rename vars with `PROD_` prefix, else wrappers use wrong creds.
- `MYSQL_PWD` visible in `ps` briefly; breaks on `"`, backtick, `\`, newline in password. Acceptable here (no mysql_config_editor); avoid those chars when rotating.
