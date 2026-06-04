# vBank Security Testing - Complete Setup Summary

**Date**: June 4, 2026  
**Application**: Sphinx vBank (Deliberately Vulnerable Banking Application)  
**Status**: Ready for Testing

---

## What's Been Prepared For You

Your vBank application has been fully analyzed and prepared for security testing. Here's what's available:

### 1. **Complete Vulnerability Documentation** 
- **File**: [attacks.md](attacks.md)
- **Content**: Detailed analysis of 8+ vulnerabilities with:
  - CWE/OWASP references
  - Exact vulnerable code locations and line numbers
  - Exploitation steps with real payloads
  - Proof-of-concept examples
  - Impact assessment for each vulnerability
- **Vulnerabilities Covered**:
  - SQL Injection (Authentication Bypass & Data Extraction)
  - Cross-Site Scripting (Stored & Reflected)
  - Remote Code Execution (preg_replace /e modifier)
  - Request Parameter Tampering
  - Client-Side Validation Bypass
  - Plain Text Password Storage
  - CSRF Vulnerabilities
  - Local File Inclusion
  - Account Number Enumeration

### 2. **Fully Containerized Application**
- **Docker Setup**: PHP 5.6 + MySQL 5.5 (legacy versions for compatibility)
- **Files**:
  - `docker-compose.yml` - Container orchestration
  - `Dockerfile` - PHP image with MySQL extensions
  - `php.ini` - Configured for legacy PHP compatibility
- **Start Command**: `./setup.sh`
- **Result**: 
  - App running on http://localhost/
  - Database on localhost:3306
  - Ready to test immediately

### 3. **Automated Testing Scripts**
- **test_exploits.py**: 
  - Automated vulnerability scanner
  - Tests all 6 major vulnerability categories
  - Can run individual tests or full suite
  - Usage: `python3 test_exploits.py`

- **vbank_utils.py**:
  - Account number XOR encoding/decoding
  - Payload library (SQL injection, XSS, etc.)
  - Quick reference data
  - Usage: `python3 vbank_utils.py info`

- **setup.sh**:
  - Automated Docker setup
  - Validates services are running
  - Displays credentials and URLs
  - Usage: `chmod +x setup.sh && ./setup.sh`

### 4. **Quick Reference Guide**
- **File**: [CHEATSHEET.md](CHEATSHEET.md)
- **Contains**:
  - One-page vulnerability reference
  - All credentials and XOR keys
  - Common payloads (copy-paste ready)
  - cURL examples
  - Burp Suite intercept points
  - Python one-liners

### 5. **Complete Setup Guide**
- **File**: [README.md](README.md)
- **Contains**:
  - Quick start instructions
  - Docker management commands
  - Manual testing procedures
  - HTTP proxy setup (Burp Suite, ZAP)
  - Troubleshooting guide
  - File structure reference
  - Attack scenarios

---

## Quick Start (5 Minutes)

```bash
# 1. Navigate to application directory
cd /home/passwd/bank_app

# 2. Make scripts executable
chmod +x setup.sh test_exploits.py vbank_utils.py

# 3. Run setup
./setup.sh

# 4. Application will be available at:
# http://localhost/
# Username: alex
# Password: 413Xp455
```

---

## Testing Paths

### Path 1: Quick Verification (10 minutes)
```bash
# Test all vulnerabilities with one command
python3 test_exploits.py

# This will verify:
# - SQL Injection in login (bypass)
# - Stored XSS in transfers
# - Loan amount tampering
# - Client-side validation bypass
# - Account enumeration
# - SQL injection in transfer remarks
```

### Path 2: Manual Testing with Browser (30 minutes)
1. Open http://localhost/
2. Try login: `' OR '1'='1` / `anything`
3. Navigate to Transfer Funds page
4. Add XSS payload in remark: `<img src=x onerror="alert('XSS')">`
5. View Account Details to see XSS execute
6. Check CHEATSHEET.md for more payloads

### Path 3: Deep Analysis with Burp Suite (1-2 hours)
1. Install Burp Suite Community
2. Configure Firefox proxy to localhost:8080
3. Use Burp to intercept requests
4. Modify parameters (amounts, accounts, etc.)
5. Execute stored XSS by viewing account history
6. Follow attacks.md for detailed exploitation

### Path 4: Command-Line Testing with cURL (30 minutes)
```bash
# Login bypass
curl -G "http://localhost/login.php" \
  --data-urlencode "username=' OR '1'='1" \
  --data-urlencode "password=anything" \
  -v

# Decode account numbers
python3 vbank_utils.py decode 252170513

# View available payloads
python3 vbank_utils.py sql
python3 vbank_utils.py xss
```

---

## Vulnerability Map (At a Glance)

| Severity | Count | Examples |
|----------|-------|----------|
| **Critical** | 3 | SQL Injection (auth), SQL Injection (transfers), RCE |
| **High** | 5 | Stored XSS, Loan tampering, Plain passwords, CSRF, Auth bypass |
| **Medium** | 2 | Path traversal, Account enumeration |

---

## Key Technical Details

### Database Credentials
```
Host: localhost:3306 (or 'mysql' in Docker)
User: root
Password: aaa
Database: vbank
```

### Application Users
| User | Password | Accounts |
|------|----------|----------|
| alex | 413Xp455 | 11111111, 33333333 |
| bob | b0BP4S5 | 22222222 |

### XOR Key (for account number decoding)
```
0x0BADC0DE (hexadecimal) = 3735928830 (decimal)
```

### Account Numbers
| Original | Xored | Balance | Owner |
|----------|-------|---------|-------|
| 11111111 | 252170513 | 1000 | alex |
| 22222222 | 243688756 | 222 | bob |
| 33333333 | 235207009 | 344 | alex |

---

## File Organization

```
/home/passwd/bank_app/
├── attacks.md              ← MAIN: Detailed vulnerability documentation
├── README.md               ← Complete setup and testing guide
├── CHEATSHEET.md          ← Quick reference (one-page)
├── THIS_FILE (index)      ← You are here
│
├── setup.sh               ← Start here: Auto-setup Docker
├── docker-compose.yml     ← Docker container definitions
├── Dockerfile             ← PHP 5.6 + MySQL setup
├── php.ini                ← PHP configuration
│
├── test_exploits.py       ← Automated testing (run after setup.sh)
├── vbank_utils.py         ← Utility: XOR, payloads, info
│
├── vbank.sql              ← Database schema & initial data
├── htdocs/                ← Web root (PHP files)
│   ├── index.php          ← Main entry point
│   ├── login.php          ← Login handler (VULNERABLE)
│   ├── htb.css
│   ├── htb.js            ← Client-side validation (BYPASSABLE)
│   └── images/
├── etc/                   ← Configuration
│   ├── config.php         ← App settings
│   └── htb.inc            ← Helper functions (has LFI vuln)
└── pages/                 ← Page templates (vulnerable templates here)
    ├── htbdetails.page    ← XSS & RCE vulnerable
    ├── htbtransfer.page   ← SQL injection vulnerable
    ├── htbloanconf.page   ← Parameter tampering vulnerable
    ├── htblogin.page
    ├── htbmain.page
    └── ... (other pages)
```

---

## Next Steps Based on Your Goals

### Goal 1: Verify Vulnerabilities Exist
```bash
./setup.sh
python3 test_exploits.py
# Done in 15 minutes - all vulnerabilities confirmed
```

### Goal 2: Document Vulnerabilities (Already Done!)
- See **attacks.md** - complete documentation with:
  - CWE/OWASP references
  - Exact vulnerable code lines
  - Exploitation methods
  - Real payloads
  - Impact assessment

### Goal 3: Learn Exploitation Techniques
1. Read attacks.md for theory
2. Use CHEATSHEET.md for quick payloads
3. Test with test_exploits.py for verification
4. Manual testing with Burp Suite for hands-on practice
5. Follow README.md for detailed walkthroughs

### Goal 4: Create Security Report
Use the information from attacks.md to create a professional security assessment:
1. Executive Summary (critical vulns, business impact)
2. Technical Findings (detailed vulnerability analysis)
3. Proof of Concept (screenshots, logs)
4. Remediation Recommendations (see attacks.md "Mitigation" sections)
5. CVSS Scoring (included in attacks.md)

---

## Common Attacks Ready to Run

### 1. SQL Injection Login Bypass
- **Time**: < 1 minute
- **Tools**: Browser or curl
- **Payload**: `' OR '1'='1`
- **Result**: Unauthorized access
- **Reference**: attacks.md Section 1

### 2. Stored XSS in Transfers
- **Time**: 5 minutes
- **Tools**: Browser
- **Payload**: `<img src=x onerror="alert('XSS')">`
- **Result**: JavaScript execution in victim browser
- **Reference**: attacks.md Section 2

### 3. Unauthorized Fund Transfer (Parameter Tampering)
- **Time**: 10 minutes
- **Tools**: Burp Suite
- **Method**: Intercept and modify amount parameter
- **Result**: Attacker-controlled transfer amount
- **Reference**: attacks.md Section 4

### 4. Account Number Decoding
- **Time**: < 1 minute
- **Tools**: Python
- **Method**: `xored_account XOR 0x0BADC0DE`
- **Result**: All account numbers enumerated
- **Reference**: attacks.md Section 7

### 5. RCE via Regex Modifier
- **Time**: 5 minutes
- **Tools**: Browser + URL parameters
- **Method**: Exploit `/e` modifier in preg_replace
- **Result**: Execute arbitrary PHP code
- **Reference**: attacks.md Section 2.2

---

## Support Resources

### In This Package
- **attacks.md** - Everything about vulnerabilities
- **README.md** - Everything about setup/testing
- **CHEATSHEET.md** - Quick reference during testing
- **test_exploits.py** - Automated testing

### External References
- OWASP TOP 10 2021: https://owasp.org/Top10/
- CWE-89 (SQL Injection): https://cwe.mitre.org/data/definitions/89.html
- CWE-79 (XSS): https://cwe.mitre.org/data/definitions/79.html

---

## Docker Management

### Start Application
```bash
./setup.sh
```

### View Logs
```bash
docker-compose logs -f php      # PHP application
docker-compose logs -f mysql    # Database
```

### Stop Application
```bash
docker-compose down
```

### Restart Services
```bash
docker-compose restart
```

### Connect to Database
```bash
mysql -h 127.0.0.1 -u root -paaa vbank
# OR
docker exec -it vbank_mysql mysql -u root -paaa vbank
```

---

## Important Reminders

✅ **DO**:
- Test in this controlled environment only
- Document your findings
- Follow the security testing methodology in attacks.md
- Use these tools for authorized testing
- Learn from the vulnerabilities

❌ **DON'T**:
- Deploy this application to production
- Test against unauthorized targets
- Ignore legal/ethical implications
- Modify code for "learning" on live systems
- Share credentials outside your team

---

## You're Ready!

Everything is prepared for comprehensive security testing:

1. ✅ Vulnerabilities identified and documented
2. ✅ Application containerized and ready to run
3. ✅ Testing scripts created and ready to use
4. ✅ phpMyAdmin included for database access
5. ✅ Quick reference guides prepared
5. ✅ Exploitation guides written

### Start Here:
```bash
./setup.sh
python3 test_exploits.py
cat attacks.md  # Read this for details
```

---

## Questions?

Refer to:
1. **attacks.md** - "How do I exploit X vulnerability?"
2. **README.md** - "How do I set up / run the app?"
3. **CHEATSHEET.md** - "What's the payload for X?"
4. **test_exploits.py** - "Show me an example of X attack"

---

**Application Status**: ✅ Ready for Testing  
**Documentation Status**: ✅ Complete  
**Testing Scripts Status**: ✅ Ready  
**Docker Setup Status**: ✅ Ready  

**Proceed with testing!**

