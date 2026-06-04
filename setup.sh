#!/bin/bash
# Setup script for vBank vulnerable application
# This script prepares the Docker environment and displays attack information

set -e

echo "========================================="
echo "vBank Vulnerable Application Setup"
echo "========================================="
echo ""

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "ERROR: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "[*] Cleaning up any previous containers..."
docker-compose down 2>/dev/null || true
docker volume rm vbank_mysql_data 2>/dev/null || true

echo "[*] Building Docker images..."
docker-compose build

echo "[*] Starting containers..."
docker-compose up -d

echo "[*] Waiting for MySQL to be ready..."
sleep 10

# Check if services are running
if docker ps | grep -q vbank_mysql; then
    echo "[✓] MySQL is running"
else
    echo "[✗] MySQL failed to start"
    docker-compose logs mysql
    exit 1
fi

if docker ps | grep -q vbank_app; then
    echo "[✓] PHP/Apache is running"
else
    echo "[✗] PHP/Apache failed to start"
    docker-compose logs php
    exit 1
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Application URL: http://localhost/"
echo "phpMyAdmin URL: http://localhost:8081/"
echo ""
echo "Default Credentials:"
echo "  Username: alex"
echo "  Password: 413Xp455"
echo ""
echo "  Username: bob"
echo "  Password: b0BP4S5"
echo ""
echo "Database Credentials:"
echo "  Host: localhost:3306"
echo "  User: root"
echo "  Password: aaa"
echo "  Database: vbank"
echo ""
echo "phpMyAdmin Access:"
echo "  URL: http://localhost:8081/"
echo "  User: root"
echo "  Password: aaa"
echo ""
echo "XOR Key: 0x0BADC0DE (3735928830)"
echo ""
echo "Known Account Numbers:"
echo "  - 11111111 (User: alex)"
echo "  - 22222222 (User: bob)"
echo "  - 33333333 (User: alex)"
echo ""
echo "For detailed vulnerability information, see: attacks.md"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To stop containers:"
echo "  docker-compose down"
echo ""
