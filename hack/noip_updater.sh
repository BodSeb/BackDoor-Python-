#!/bin/bash
# No-IP Updater for Termux

USERNAME="your-email@gmail.com"  # ЗАМЕНИТЕ НА СВОЙ!
PASSWORD="your-password"         # ЗАМЕНИТЕ НА СВОЙ!
HOSTNAME="herculles.ddns.net"
LOG_FILE="/data/data/com.termux/files/home/noip_log.txt"

echo "======================================="
echo "🔄 SWILL No-IP Auto Updater"
echo "🌐 Domain: $HOSTNAME"
echo "======================================="

# Получаем текущий IP
CURRENT_IP=$(curl -s ifconfig.me)
echo "📡 Current IP: $CURRENT_IP"

# Обновляем No-IP
echo "🔄 Updating No-IP..."
RESPONSE=$(curl -s --user "$USERNAME:$PASSWORD" "https://dynupdate.no-ip.com/nic/update?hostname=$HOSTNAME&myip=$CURRENT_IP")

# Логируем
echo "$(date '+%Y-%m-%d %H:%M:%S') - IP: $CURRENT_IP - Response: $RESPONSE" >> "$LOG_FILE"

# Обрабатываем ответ
case $RESPONSE in
    good*)
        echo "✅ SUCCESS: IP updated to $CURRENT_IP"
        ;;
    nochg*)
        echo "ℹ️  INFO: No change needed"
        ;;
    nohost)
        echo "❌ ERROR: Hostname doesn't exist"
        ;;
    badauth)
        echo "❌ ERROR: Bad username/password"
        ;;
    abuse)
        echo "❌ ERROR: Abuse detected"
        ;;
    911)
        echo "❌ ERROR: No-IP server error"
        ;;
    *)
        echo "❌ UNKNOWN: $RESPONSE"
        ;;
esac

echo "📋 Log file: $LOG_FILE"
echo "======================================="
