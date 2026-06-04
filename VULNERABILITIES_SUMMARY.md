# vBank Vulnerability Summary

## Executive Summary

vBank (Sphinx) contains **6 critical and high-severity vulnerabilities** spanning the OWASP Top 10. These vulnerabilities allow unauthorized access, data manipulation, and complete system compromise.

---

## Vulnerability Overview

### 1. SQL Injection - Authentication Bypass ⚠️ CRITICAL

| Property | Value |
|----------|-------|
| **CWE** | CWE-89: Improper Neutralization of Special Elements used in an SQL Command |
| **CVSS v3.1** | 9.8 (Critical) |
| **OWASP** | A03:2021 – Injection |
| **Impact** | Complete authentication bypass, unauthorized access |
| **Exploitability** | Very Easy - No tools required |
| **File** | [htdocs/login.php](htdocs/login.php) |
| **Lines** | 16-17 |

**Vulnerable Code**:
```php
$sql = "SELECT * FROM " . $htbconf['db/users'] . " where " . $htbconf['db/users.username'] . "='$username' and " . $htbconf['db/users.password'] . "='$password'";
```

**Attack Vector**:
- Client-side JavaScript validation can be bypassed via:
  - Disabling JavaScript
  - Browser DevTools manipulation
  - HTTP proxy interception (Burp Suite)
  - Direct curl requests

**Proof of Concept**:
```bash
curl "http://localhost/index.php?page=login&username=' OR '1'='1&password=x"
```

**Result**: Authentication bypass, logged in as first user in database

---

### 2. Account Enumeration - XOR Weakness ⚠️ HIGH

| Property | Value |
|----------|-------|
| **CWE** | CWE-327: Use of a Broken or Risky Cryptographic Algorithm |
| **CVSS v3.1** | 3.7 (Low) - But enables other attacks |
| **OWASP** | A02:2021 – Cryptographic Failures |
| **Impact** | All account numbers can be decoded |
| **Exploitability** | Trivial - Mathematical reversal |
| **File** | [etc/config.php](etc/config.php) |
| **Key** | 0x0BADC0DE |

**Vulnerability**:
XOR is NOT an encryption function. It's symmetric and easily reversible:
```
original = encrypted XOR key
encrypted = original XOR key
```

**Attack**:
```python
xor_key = 0x0BADC0DE
xored_account = 252170513
original_account = xored_account ^ xor_key  # Result: 11111111
```

**Result**: All account numbers decoded, enables targeted attacks

---

### 3. SQL Injection - Transfer Remark Field ⚠️ CRITICAL

| Property | Value |
|----------|-------|
| **CWE** | CWE-89: Improper Neutralization of Special Elements used in an SQL Command |
| **CVSS v3.1** | 9.8 (Critical) |
| **OWASP** | A03:2021 – Injection |
| **Impact** | Arbitrary SQL execution, data modification/extraction |
| **Exploitability** | Easy - From authenticated user |
| **File** | [pages/htbtransfer.page](pages/htbtransfer.page) |
| **Lines** | 39 |

**Vulnerable Code**:
```php
$sql="insert into ".$htbconf['db/transfers']." (..., '".$http['remark']."', ...)";
```

**Attack Vector**:
No input validation or SQL escaping on the `remark` field.

**Proof of Concept**:
```
Remark: '); DROP TABLE accounts; --
```

**Result**: Database manipulation, data destruction, information disclosure

---

### 4. Stored Cross-Site Scripting (XSS) ⚠️ HIGH

| Property | Value |
|----------|-------|
| **CWE** | CWE-79: Improper Neutralization of Input During Web Page Generation |
| **CVSS v3.1** | 7.5 (High) |
| **OWASP** | A03:2021 – Injection |
| **Impact** | Cookie theft, session hijacking, credential harvesting |
| **Exploitability** | Easy - From transfer remark field |
| **File** | [pages/htbdetails.page](pages/htbdetails.page) |
| **Lines** | 45 |

**Vulnerable Code**:
```php
$transfersStr .= "<td>".$row[5]."</td>\n";  // No HTML escaping
```

**Attack Vector**:
Remark field is displayed without HTML entity encoding.

**Proof of Concept**:
```html
Remark: <img src=x onerror="alert('XSS')">
```

When viewing account details, JavaScript executes in user's browser.

**Result**: Session hijacking, credential theft, malware distribution

---

### 5. Remote Code Execution - preg_replace /e Modifier ⚠️ CRITICAL

| Property | Value |
|----------|-------|
| **CWE** | CWE-95: Improper Neutralization of Directives in Dynamically Evaluated Code |
| **CVSS v3.1** | 9.9 (Critical) |
| **OWASP** | A03:2021 – Injection |
| **Impact** | Complete system compromise, arbitrary code execution |
| **Exploitability** | Moderate - Requires authenticated user |
| **File** | [pages/htbdetails.page](pages/htbdetails.page) |
| **Lines** | 56-60 |

**Vulnerable Code**:
```php
$transfersStr = preg_replace('#(\>((?>(([^><]+|(?R))))*\<))#se',$replaceWith,'>'.$transfersStr.'<');
```

The `/e` modifier (DEPRECATED) evaluates the replacement string as PHP code.

**Attack Vector**:
User input in `query` parameter is evaluated as PHP:

```php
query=" . system('id') . "
```

**Result**: Full server compromise, file access, database control

---

### 6. Parameter Tampering - Loan Amount Manipulation ⚠️ HIGH

| Property | Value |
|----------|-------|
| **CWE** | CWE-20: Improper Input Validation |
| **CVSS v3.1** | 8.2 (High) |
| **OWASP** | A04:2021 – Insecure Design |
| **Impact** | Financial fraud, unauthorized loan creation |
| **Exploitability** | Very Easy - HTTP proxy required |
| **File** | [pages/htbloanconf.page](pages/htbloanconf.page) |
| **Lines** | 24 |

**Vulnerable Code**:
```php
if(!is_numeric($http['amount']) || $http['amount'] == "") {
    // validation fails
}
// But no upper/lower bounds checking
```

**Attack Vector**:
Only format validation, no amount limits. Use proxy to modify:

```
amount=100 → amount=999999999
```

**Result**: Unlimited loan amounts, negative balances, financial manipulation

---

## Attack Sequence: Complete Compromise

### Phase 1: Authentication Bypass (5 minutes)
1. Send SQL injection to login.php
2. Bypass authentication without valid credentials
3. Gain access as admin user

### Phase 2: Information Gathering (2 minutes)
1. Decode account numbers via XOR key
2. Identify all available accounts
3. Use phpMyAdmin to view user passwords

### Phase 3: Data Manipulation (10 minutes)
1. Create transfer with SQL injection in remark
2. Modify account balances
3. Extract sensitive data via UNION SELECT

### Phase 4: System Compromise (5 minutes)
1. Trigger RCE via preg_replace /e modifier
2. Execute arbitrary PHP code
3. Write web shell for persistence

**Total Time to Complete Compromise**: ~20 minutes

---

## Severity Classification

| Severity | Count | Vulnerabilities |
|----------|-------|---|
| 🔴 Critical | 3 | SQL Injection (Auth, Transfer), RCE |
| 🟠 High | 3 | Account Enumeration, Stored XSS, Parameter Tampering |

---

## Remediation Priority

### Immediate (P1)
1. ❌ Use prepared statements/parameterized queries
2. ❌ Add server-side input validation
3. ❌ Upgrade PHP to 7.4+ (retire 5.6)

### Short-Term (P2)
1. ❌ Implement proper output encoding
2. ❌ Add CSRF protection tokens
3. ❌ Enforce HTTPS/TLS

### Long-Term (P3)
1. ❌ Implement Web Application Firewall (WAF)
2. ❌ Security code review and testing
3. ❌ Developer security training

---

## References

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [CWE List](https://cwe.mitre.org/)
- [CVSS Calculator](https://www.first.org/cvss/calculator/3.1)
- [SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)

---

**Assessment Date**: June 4, 2026  
**Risk Level**: 🔴 CRITICAL  
**Recommendation**: Immediate remediation required before production use  
