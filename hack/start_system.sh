#!/bin/bash
# SWILL System Starter

echo "🚀 Starting SWILL System..."
echo "📅 $(date)"

# Проверяем зависимости
if ! command -v python &> /dev/null; then
    echo "❌ Python not found. Installing..."
    pkg install -y python
fi

if ! command -v ssh &> /dev/null; then
    echo "❌ SSH not found. Installing..."
    pkg install -y openssh
fi

echo "✅ Dependencies checked"

# Запускаем систему в фоне
echo "🖥️  Starting SWILL Server..."
python server.py &

echo "🌐 Starting Serveo Tunnel..."
./serveo_tunnel.sh &

echo "✅ SWILL System started"
echo "🔗 Serveo Domain: swill.serveo.net"
echo "🎮 Ready for connections..."

# Ждем
wait
