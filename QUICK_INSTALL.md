# Быстрая установка с GitHub

## Один шаг - полная установка! 🚀

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/scripts/install_from_github.sh | sudo bash
```

**Замените:**
- `YOUR_USERNAME` - ваш GitHub username
- `YOUR_REPO` - название репозитория

## Что произойдет:

1. ✅ Скрипт загрузит проект с GitHub
2. ✅ Установит все зависимости (Docker, Nginx и др.)
3. ✅ Настроит и запустит сервер
4. ✅ Инициализирует базу данных

## После установки:

```bash
# 1. Настройте безопасность (рекомендуется)
sudo /opt/proxy/scripts/security.sh

# 2. Настройте SSL
sudo /opt/proxy/scripts/setup_ssl.sh your-domain.com

# 3. Готово! Откройте https://your-domain.com/docs
```

## Примеры:

### Публичный репозиторий

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/proxy/main/scripts/install_from_github.sh | sudo bash
```

### С указанием параметров

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/proxy/main/scripts/install_from_github.sh | \
  sudo GITHUB_USER=yourusername GITHUB_REPO_NAME=proxy bash
```

### Другая ветка

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/proxy/main/scripts/install_from_github.sh | \
  sudo BRANCH=develop bash
```

## Нужна помощь?

- **Подробная инструкция**: [INSTALL_FROM_GITHUB.md](INSTALL_FROM_GITHUB.md)
- **Устранение неполадок**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
