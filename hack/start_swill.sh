#!/bin/bash
# SWILL Auto Starter for Termux

echo "🚀 Starting SWILL System..."
echo "📅 $(date)"

# Проверяем зависимости
if ! command -v python &> /dev/null; then
    echo "❌ Python not found. Installing..."
    pkg install -y python
fi

if ! command -v curl &> /dev/null; then
    echo "❌ curl not found. Installing..."
    pkg install -y curl
fi

# Обновляем No-IP
echo "🔄 Updating No-IP..."
chmod +x noip_updater.sh
./noip_updater.sh

# Запускаем сервер
echo "🖥️  Starting SWILL Server..."
python server.py

echo "🔚 SWILL System Stopped"
