#!/bin/bash

###############################################################################
# Скрипт автоматической настройки безопасности Ubuntu
# Для Ubuntu 20.04/22.04 LTS
#
# Этот скрипт настраивает базовую безопасность операционной системы:
# - Firewall (UFW)
# - Fail2ban (защита от брут-форса)
# - Автоматические обновления безопасности
# - Настройки SSH
# - Ограничения ресурсов
# - Аудит системы
###############################################################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
LOG_FILE="/var/log/proxy_security_setup.log"
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "Пожалуйста, запустите скрипт с правами root: sudo $0"
    fi
}

# Проверка ОС
check_os() {
    if [ ! -f /etc/os-release ]; then
        error "Не удалось определить операционную систему"
    fi
    
    . /etc/os-release
    
    if [ "$ID" != "ubuntu" ]; then
        warning "Скрипт протестирован на Ubuntu. Текущая ОС: $PRETTY_NAME"
        read -p "Продолжить установку? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Операционная система: $PRETTY_NAME"
}

# Обновление системы
update_system() {
    log "Обновление системы..."
    apt-get update -qq
    apt-get upgrade -y -qq
    log "Система обновлена"
}

# Настройка Firewall (UFW)
setup_firewall() {
    log "Настройка Firewall (UFW)..."
    
    # Установка UFW если не установлен
    if ! command -v ufw &> /dev/null; then
        apt-get install -y -qq ufw
    fi
    
    # Сброс правил (осторожно!)
    # ufw --force reset
    
    # Базовые правила
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1
    
    # Разрешаем SSH (важно сделать первым!)
    ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1
    
    # Разрешаем HTTP и HTTPS
    ufw allow 80/tcp comment 'HTTP' > /dev/null 2>&1
    ufw allow 443/tcp comment 'HTTPS' > /dev/null 2>&1
    
    # Включаем firewall
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable > /dev/null 2>&1
    fi
    
    # Показываем статус
    ufw status numbered
    
    log "Firewall настроен и включен"
}

# Установка и настройка Fail2ban
setup_fail2ban() {
    log "Установка и настройка Fail2ban..."
    
    # Установка fail2ban
    if ! command -v fail2ban-server &> /dev/null; then
        apt-get install -y -qq fail2ban
    fi
    
    # Создание локальной конфигурации
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Время бана в секундах (1 час)
bantime = 3600
# Время окна для подсчета попыток (10 минут)
findtime = 600
# Количество неудачных попыток
maxretry = 5
# Email для уведомлений (опционально)
# destemail = admin@example.com
# sendername = Fail2Ban
# action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 7200

[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 10
findtime = 600
bantime = 3600

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
EOF
    
    # Перезапуск fail2ban
    systemctl enable fail2ban > /dev/null 2>&1
    systemctl restart fail2ban > /dev/null 2>&1
    
    # Проверка статуса
    if systemctl is-active --quiet fail2ban; then
        log "Fail2ban установлен и запущен"
        info "Проверка статуса: fail2ban-client status"
    else
        warning "Fail2ban не запустился. Проверьте: systemctl status fail2ban"
    fi
}

# Настройка автоматических обновлений безопасности
setup_auto_updates() {
    log "Настройка автоматических обновлений безопасности..."
    
    # Установка unattended-upgrades
    apt-get install -y -qq unattended-upgrades
    
    # Настройка автоматических обновлений
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF
    
    # Включение автоматических обновлений
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    log "Автоматические обновления безопасности настроены"
    info "Обновления будут устанавливаться автоматически каждый день"
}

# Настройка SSH
setup_ssh() {
    log "Настройка SSH безопасности..."
    
    local ssh_config="/etc/ssh/sshd_config"
    local ssh_backup="${ssh_config}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Создание резервной копии
    cp "$ssh_config" "$ssh_backup"
    
    # Настройки безопасности SSH
    cat >> "$ssh_config" << 'EOF'

# Настройки безопасности (добавлено скриптом security.sh)
# Отключение root логина по паролю (рекомендуется использовать ключи)
# PermitRootLogin prohibit-password

# Отключение пустых паролей
PermitEmptyPasswords no

# Отключение X11 forwarding (если не нужен)
X11Forwarding no

# Максимальное количество попыток входа
MaxAuthTries 3

# Таймаут для неактивных сессий
ClientAliveInterval 300
ClientAliveCountMax 2

# Отключение DNS lookup (ускоряет подключение)
UseDNS no

# Отключение менее безопасных протоколов
Protocol 2

# Отключение доступа для пользователей без shell
AllowUsers root
# Или разрешить конкретных пользователей:
# AllowUsers user1 user2
EOF
    
    # Вопрос об отключении root логина
    echo
    read -p "Отключить вход root по паролю? (рекомендуется, y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' "$ssh_config"
        sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' "$ssh_config"
        warning "Root логин по паролю отключен. Убедитесь, что у вас есть SSH ключ!"
    fi
    
    # Тестирование конфигурации
    if sshd -t > /dev/null 2>&1; then
        systemctl restart sshd
        log "SSH настроен безопасно"
        info "Резервная копия: $ssh_backup"
    else
        error "Ошибка в конфигурации SSH. Восстановите из резервной копии: $ssh_backup"
    fi
}

# Настройка ограничений ресурсов
setup_resource_limits() {
    log "Настройка ограничений ресурсов..."
    
    cat >> /etc/security/limits.conf << 'EOF'

# Ограничения ресурсов (добавлено скриптом security.sh)
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
root soft nofile 65536
root hard nofile 65536
EOF
    
    log "Ограничения ресурсов настроены"
}

# Настройка sysctl для безопасности
setup_sysctl() {
    log "Настройка параметров ядра для безопасности..."
    
    local sysctl_file="/etc/sysctl.d/99-security.conf"
    
    cat > "$sysctl_file" << 'EOF'
# Настройки безопасности сети (добавлено скриптом security.sh)

# Отключение IP forwarding (если не нужен)
# net.ipv4.ip_forward = 0

# Защита от SYN flood атак
net.ipv4.tcp_syncookies = 1

# Отключение перенаправления пакетов
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Защита от IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Отключение ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Отключение source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Логирование подозрительных пакетов
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Защита от SYN flood
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Уменьшение времени для TIME_WAIT соединений
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Увеличение диапазона портов
net.ipv4.ip_local_port_range = 10000 65535

# Защита от ping flood
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
EOF
    
    # Применение настроек
    sysctl -p "$sysctl_file" > /dev/null 2>&1
    
    log "Параметры ядра настроены"
}

# Установка и настройка auditd
setup_auditd() {
    log "Настройка аудита системы (auditd)..."
    
    # Установка auditd
    if ! command -v auditd &> /dev/null; then
        apt-get install -y -qq auditd audispd-plugins
    fi
    
    # Базовая конфигурация
    cat > /etc/audit/rules.d/99-security.rules << 'EOF'
# Правила аудита безопасности (добавлено скриптом security.sh)

# Мониторинг изменений в системных файлах
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity
-w /etc/ssh/sshd_config -p wa -k sshd_config

# Мониторинг сетевых конфигураций
-w /etc/network/interfaces -p wa -k network
-w /etc/hosts -p wa -k hosts
-w /etc/hostname -p wa -k hostname

# Мониторинг изменений в критичных директориях
-w /usr/bin -p wa -k bin_modifications
-w /usr/sbin -p wa -k sbin_modifications
-w /bin -p wa -k bin_modifications
-w /sbin -p wa -k sbin_modifications

# Мониторинг системных вызовов
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change
-a always,exit -F arch=b32 -S clock_settime -k time_change

# Мониторинг изменений в системе
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system_changes
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system_changes
EOF
    
    # Перезапуск auditd
    systemctl enable auditd > /dev/null 2>&1
    systemctl restart auditd > /dev/null 2>&1
    
    log "Auditd настроен и запущен"
    info "Просмотр логов: ausearch -k security"
}

# Настройка AppArmor
setup_apparmor() {
    log "Проверка и настройка AppArmor..."
    
    if command -v apparmor_status &> /dev/null; then
        # Включение AppArmor
        systemctl enable apparmor > /dev/null 2>&1
        systemctl start apparmor > /dev/null 2>&1
        
        log "AppArmor включен"
        info "Статус: apparmor_status"
    else
        warning "AppArmor не установлен. Установите: apt-get install apparmor apparmor-utils"
    fi
}

# Настройка логирования
setup_logging() {
    log "Настройка логирования..."
    
    # Настройка ротации логов
    cat > /etc/logrotate.d/proxy-security << 'EOF'
/var/log/proxy_*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOF
    
    # Настройка rsyslog для централизованного логирования (опционально)
    # Можно настроить отправку логов на внешний сервер
    
    log "Логирование настроено"
}

# Отключение ненужных сервисов
disable_unnecessary_services() {
    log "Проверка ненужных сервисов..."
    
    local services=(
        "bluetooth"
        "cups"
        "avahi-daemon"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" > /dev/null 2>&1; then
            info "Отключение сервиса: $service"
            systemctl stop "$service" > /dev/null 2>&1 || true
            systemctl disable "$service" > /dev/null 2>&1 || true
        fi
    done
    
    log "Ненужные сервисы отключены"
}

# Создание скрипта для мониторинга безопасности
create_security_monitor() {
    log "Создание скрипта мониторинга безопасности..."
    
    cat > /usr/local/bin/security-check.sh << 'EOF'
#!/bin/bash
# Скрипт проверки безопасности системы

echo "=== Проверка безопасности системы ==="
echo

echo "1. Статус Firewall:"
ufw status | head -5
echo

echo "2. Статус Fail2ban:"
fail2ban-client status 2>/dev/null || echo "Fail2ban не запущен"
echo

echo "3. Последние неудачные попытки входа:"
grep "Failed password" /var/log/auth.log | tail -5 || echo "Нет записей"
echo

echo "4. Активные SSH сессии:"
who
echo

echo "5. Последние логины:"
last | head -10
echo

echo "6. Статус автоматических обновлений:"
systemctl status unattended-upgrades --no-pager | head -5
echo

echo "7. Проверка открытых портов:"
ss -tulpn | grep LISTEN | head -10
echo
EOF
    
    chmod +x /usr/local/bin/security-check.sh
    
    log "Скрипт мониторинга создан: /usr/local/bin/security-check.sh"
}

# Вывод итоговой информации
print_summary() {
    echo
    echo "==================================================================="
    echo -e "${GREEN}✅ Настройка безопасности завершена!${NC}"
    echo "==================================================================="
    echo
    echo "📋 Настроенные компоненты:"
    echo "   ✅ Firewall (UFW) - настроен и включен"
    echo "   ✅ Fail2ban - защита от брут-форса"
    echo "   ✅ Автоматические обновления безопасности"
    echo "   ✅ SSH - безопасная конфигурация"
    echo "   ✅ Ограничения ресурсов"
    echo "   ✅ Параметры ядра (sysctl)"
    echo "   ✅ Auditd - аудит системы"
    echo "   ✅ Логирование"
    echo
    echo "🔧 Полезные команды:"
    echo "   - Проверка безопасности: /usr/local/bin/security-check.sh"
    echo "   - Статус firewall: ufw status"
    echo "   - Статус fail2ban: fail2ban-client status"
    echo "   - Просмотр забаненных IP: fail2ban-client status sshd"
    echo "   - Разбан IP: fail2ban-client set sshd unbanip <IP>"
    echo
    echo "⚠️  Важные замечания:"
    echo "   1. Проверьте SSH доступ - убедитесь, что можете подключиться"
    echo "   2. Если отключили root логин, убедитесь, что есть SSH ключ"
    echo "   3. Регулярно проверяйте логи: /var/log/auth.log"
    echo "   4. Настройте мониторинг для критичных событий"
    echo
    echo "📝 Лог установки: $LOG_FILE"
    echo "==================================================================="
}

# Главная функция
main() {
    clear
    echo "==================================================================="
    echo -e "${GREEN}Настройка безопасности Ubuntu${NC}"
    echo "==================================================================="
    echo
    warning "Этот скрипт изменит настройки безопасности системы!"
    echo
    read -p "Продолжить? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    check_root
    check_os
    
    log "Начало настройки безопасности..."
    
    update_system
    setup_firewall
    setup_fail2ban
    setup_auto_updates
    setup_ssh
    setup_resource_limits
    setup_sysctl
    setup_auditd
    setup_apparmor
    setup_logging
    disable_unnecessary_services
    create_security_monitor
    
    print_summary
    
    log "Настройка безопасности завершена. Лог сохранен в $LOG_FILE"
}

# Запуск
main "$@"
