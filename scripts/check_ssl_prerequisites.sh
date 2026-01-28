#!/bin/bash

###############################################################################
# Скрипт проверки предварительных условий для получения SSL сертификата
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

if [ -z "$1" ]; then
    error "Использование: $0 <domain>"
    echo "Пример: $0 example.com"
    exit 1
fi

DOMAIN=$1

echo "==================================================================="
echo "Проверка предварительных условий для SSL сертификата"
echo "Домен: $DOMAIN"
echo "==================================================================="
echo

# Проверка 1: DNS записи
log "1. Проверка DNS записей..."
DNS_IP=$(dig +short $DOMAIN | tail -1)
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "не определен")

if [ -z "$DNS_IP" ]; then
    error "DNS запись для $DOMAIN не найдена"
    echo "   Настройте A запись для $DOMAIN на IP вашего сервера"
else
    log "   DNS запись найдена: $DNS_IP"
    if [ "$DNS_IP" = "$SERVER_IP" ]; then
        log "   ✓ DNS указывает на этот сервер"
    else
        warning "   DNS IP ($DNS_IP) не совпадает с IP сервера ($SERVER_IP)"
        echo "   Убедитесь, что DNS правильно настроен"
    fi
fi
echo

# Проверка 2: Firewall
log "2. Проверка Firewall..."
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        if ufw status | grep -q "80/tcp"; then
            log "   ✓ Порт 80 открыт в firewall"
        else
            error "   Порт 80 НЕ открыт в firewall"
            echo "   Выполните: sudo ufw allow 80/tcp"
        fi
        if ufw status | grep -q "443/tcp"; then
            log "   ✓ Порт 443 открыт в firewall"
        else
            warning "   Порт 443 не открыт (не критично для получения сертификата)"
        fi
    else
        warning "   Firewall не активен"
    fi
else
    warning "   UFW не установлен"
fi
echo

# Проверка 3: Nginx
log "3. Проверка Nginx..."
if systemctl is-active --quiet nginx; then
    log "   ✓ Nginx запущен"
    
    # Проверка конфигурации
    if nginx -t > /dev/null 2>&1; then
        log "   ✓ Конфигурация Nginx корректна"
    else
        error "   Ошибка в конфигурации Nginx"
        echo "   Выполните: sudo nginx -t"
    fi
    
    # Проверка порта 80
    if netstat -tuln | grep -q ":80 "; then
        log "   ✓ Nginx слушает порт 80"
    else
        error "   Nginx НЕ слушает порт 80"
    fi
else
    error "   Nginx не запущен"
    echo "   Выполните: sudo systemctl start nginx"
fi
echo

# Проверка 4: Доступность домена
log "4. Проверка доступности домена..."
if curl -I -s --max-time 10 http://${DOMAIN} > /dev/null 2>&1; then
    log "   ✓ Домен доступен через HTTP"
    
    # Проверка /.well-known/acme-challenge/
    TEST_FILE="/var/www/certbot/test-$(date +%s).txt"
    echo "test" > "$TEST_FILE" 2>/dev/null || true
    
    if curl -s --max-time 10 "http://${DOMAIN}/.well-known/acme-challenge/$(basename $TEST_FILE)" > /dev/null 2>&1; then
        log "   ✓ Путь /.well-known/acme-challenge/ доступен"
    else
        error "   Путь /.well-known/acme-challenge/ НЕ доступен"
        echo "   Проверьте конфигурацию Nginx для этого пути"
    fi
    
    rm -f "$TEST_FILE" 2>/dev/null || true
else
    error "   Домен НЕ доступен через HTTP"
    echo "   Проверьте:"
    echo "     - DNS записи"
    echo "     - Firewall (порт 80)"
    echo "     - Nginx запущен"
    echo "     - Провайдер не блокирует порт 80"
fi
echo

# Проверка 5: Провайдер/облако
log "5. Проверка блокировки портов провайдером..."
info "   Некоторые провайдеры/облачные платформы блокируют порты"
info "   Проверьте настройки Security Groups / Firewall в панели управления"
echo

# Итоговая рекомендация
echo "==================================================================="
if curl -I -s --max-time 10 http://${DOMAIN} > /dev/null 2>&1 && \
   ufw status | grep -q "80/tcp" && \
   systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Все проверки пройдены! Можно получать SSL сертификат.${NC}"
    echo
    echo "Выполните:"
    echo "  sudo /opt/proxy/scripts/setup_ssl.sh $DOMAIN"
else
    echo -e "${YELLOW}⚠ Некоторые проверки не пройдены.${NC}"
    echo
    echo "Рекомендации:"
    echo "  1. Убедитесь, что DNS настроен правильно"
    echo "  2. Откройте порт 80: sudo ufw allow 80/tcp"
    echo "  3. Запустите Nginx: sudo systemctl start nginx"
    echo "  4. Проверьте настройки Security Groups в панели провайдера"
    echo
    echo "Или используйте standalone режим:"
    echo "  sudo certbot certonly --standalone -d $DOMAIN"
fi
echo "==================================================================="
