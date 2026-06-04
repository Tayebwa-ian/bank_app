# phpMyAdmin Integration Summary

**Added**: June 4, 2026  
**Component**: phpMyAdmin (Latest) Web Database Interface

---

## What Was Added

### Docker Service
- **Service Name**: phpmyadmin
- **Image**: phpmyadmin:latest
- **Container Name**: vbank_phpmyadmin
- **Port**: 8081 (accessible at http://localhost:8081/)
- **Dependencies**: MySQL 5.5 service

### Configuration
```yaml
phpmyadmin:
  image: phpmyadmin:latest
  container_name: vbank_phpmyadmin
  depends_on:
    mysql:
      condition: service_healthy
  ports:
    - "8081:80"
  environment:
    PMA_HOST: mysql
    PMA_USER: root
    PMA_PASSWORD: aaa
    PMA_DB: vbank
  networks:
    - vbank_network
```

---

## Access Information

| Property | Value |
|----------|-------|
| URL | http://localhost:8081/ |
| Username | root |
| Password | aaa |
| Server | mysql |
| Database | vbank |

---

## Files Modified

### Core Configuration
- **docker-compose.yml** - Added phpmyadmin service definition

### Documentation Updates
1. **README.md**
   - Added phpMyAdmin access section
   - Updated Docker management commands to include phpmyadmin logs
   - Added phpmyadmin access instructions

2. **CHEATSHEET.md**
   - Added phpMyAdmin URL to access section
   - Added new "Database Tools & Access" section with:
     - phpMyAdmin interface info
     - Quick SQL queries for testing
     - MySQL command-line access
   - Updated Docker commands to include phpmyadmin

3. **START_HERE.md**
   - Added phpMyAdmin access credentials

4. **SETUP_COMPLETE.txt**
   - Added phpMyAdmin container info to Docker setup description
   - Added phpMyAdmin URL to credentials section

5. **INDEX.md**
   - Updated "You're Ready!" section to mention phpMyAdmin

6. **setup.sh**
   - Enhanced output to display phpMyAdmin URL and credentials

---

## Features & Benefits

### Database Exploration
- Visual browsing of database structure
- View all tables: users, accounts, transfers, loans, etc.
- See plain text passwords in users table
- View account balances and transaction history

### SQL Query Execution
- Execute custom SQL queries directly
- Test SQL injection payloads
- Verify exploitation results
- Modify data for testing scenarios

### Security Testing Applications
- **Verify Vulnerabilities**: Confirm SQL injection results
- **Password Extraction**: View all plain text passwords
- **Data Tampering**: Modify accounts, transfers, balances
- **Privilege Testing**: Test what can be accessed/modified
- **Persistence Testing**: Insert backdoor accounts
- **Evidence Collection**: Screenshot database state

### Testing Scenarios

**Scenario 1: Verify SQL Injection Results**
1. Log in to phpMyAdmin
2. Navigate to transfers table
3. Look for injected SQL payloads in remark field
4. Confirm data extraction worked

**Scenario 2: Extract User Credentials**
1. Open phpMyAdmin
2. Go to "users" table
3. View all usernames and plain-text passwords
4. Prove authentication bypass impact

**Scenario 3: Check Account Balances**
1. Browse "accounts" table
2. Note original balances (11111111: 1000, 22222222: 222, etc.)
3. After transfer exploitation, verify balance changes

**Scenario 4: Create Backdoor Account**
1. phpMyAdmin > users table > Insert
2. Add new admin user
3. Use backdoor account for persistence

---

## Quick Reference

### Access phpMyAdmin
```
Open browser: http://localhost:8081/
User: root
Password: aaa
Click "Connect"
```

### View Database Tables
```
Left panel > vbank > [Table name]
```

### Run SQL Query
```
Top menu > SQL
Enter query
Click "Go"
```

### Common Queries for Testing
```sql
-- See all users and passwords
SELECT id, username, password, name FROM users;

-- See all accounts
SELECT * FROM accounts;

-- See all transfers
SELECT * FROM transfers ORDER BY time DESC;

-- Find XSS/SQL injection payloads in remarks
SELECT * FROM transfers WHERE remark LIKE '%script%' 
   OR remark LIKE '%<img%' 
   OR remark LIKE '%UNION%';
```

---

## Docker Commands

```bash
# View phpMyAdmin logs
docker-compose logs -f phpmyadmin

# Restart just phpMyAdmin
docker-compose restart phpmyadmin

# Rebuild all services
docker-compose build --no-cache

# Full reset
docker-compose down -v
./setup.sh
```

---

## Troubleshooting

### phpMyAdmin Won't Start
```bash
# Check logs
docker-compose logs phpmyadmin

# Verify MySQL is running
docker-compose ps

# Verify MySQL is healthy
docker exec vbank_mysql mysqladmin ping -u root -paaa

# Rebuild
docker-compose build --no-cache
docker-compose up -d phpmyadmin
```

### Can't Connect to Database from phpMyAdmin
- Ensure MySQL container is running: `docker-compose ps`
- Check MySQL is healthy: `docker-compose logs mysql | grep -i healthy`
- Verify credentials: User: root, Pass: aaa
- Verify Server: mysql (not localhost or 127.0.0.1)

### Port 8081 Already in Use
```bash
# Find what's using port 8081
lsof -i :8081

# Kill process or change port in docker-compose.yml
# Change "8081:80" to "8082:80" for example
```

---

## Integration Verification

### Verify Installation
```bash
# After running ./setup.sh, verify all services:
docker-compose ps

# Output should show:
# vbank_mysql       mysql:5.5        Up      3306/tcp
# vbank_app         PHP/Apache       Up      80/tcp
# vbank_phpmyadmin  phpMyAdmin       Up      8081/tcp
```

### Test Access
```bash
# Test application
curl http://localhost/

# Test phpMyAdmin
curl http://localhost:8081/

# Test MySQL
mysql -h 127.0.0.1 -u root -paaa vbank -e "SELECT COUNT(*) FROM users;"
```

---

## Summary

phpMyAdmin has been successfully integrated into the vBank security testing environment. It provides:

✅ **Visual database browser** for exploring vulnerability impacts  
✅ **SQL query interface** for testing injection payloads  
✅ **Direct data access** to view passwords and account information  
✅ **Data modification** capabilities for creating test scenarios  
✅ **Evidence collection** for security reports  

**All documentation has been updated** with access information and usage examples.

Use phpMyAdmin to enhance your security testing workflow and verify exploitation results.

---

**Setup**: ✅ Complete  
**Documentation**: ✅ Updated  
**Ready**: ✅ Yes

Access phpMyAdmin at: **http://localhost:8081/**

