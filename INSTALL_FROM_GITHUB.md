# Установка с GitHub

## Быстрая установка

### Способ 1: Прямая загрузка и установка (рекомендуется)

Замените `USERNAME` и `REPO` на ваши данные:

```bash
# Вариант 1: Интерактивный режим (скрипт спросит данные)
curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh | sudo bash

# Вариант 2: С параметрами через переменные окружения
curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh | \
  sudo bash -s -- USERNAME REPO_NAME [BRANCH]

# Вариант 3: Через переменные окружения (может не работать с sudo)
GITHUB_USER=USERNAME GITHUB_REPO_NAME=REPO bash <(curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh)
```

**Пример:**
```bash
# Интерактивный режим
curl -fsSL https://raw.githubusercontent.com/esovgirenko/proxy/main/scripts/install_from_github.sh | sudo bash

# С параметрами
curl -fsSL https://raw.githubusercontent.com/esovgirenko/proxy/main/scripts/install_from_github.sh | \
  sudo bash -s -- esovgirenko proxy main
```

### Способ 2: Загрузка скрипта и запуск (рекомендуется для надежности)

```bash
# Загрузить скрипт
wget https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh

# Сделать исполняемым
chmod +x install_from_github.sh

# Запустить с параметрами
sudo ./install_from_github.sh USERNAME REPO_NAME [BRANCH]

# Или интерактивно
sudo ./install_from_github.sh
```

**Пример:**
```bash
wget https://raw.githubusercontent.com/esovgirenko/proxy/main/scripts/install_from_github.sh
chmod +x install_from_github.sh
sudo ./install_from_github.sh esovgirenko proxy
```

### Способ 3: Клонирование и установка

```bash
# Клонировать репозиторий
git clone https://github.com/USERNAME/REPO.git /tmp/proxy
cd /tmp/proxy

# Запустить установку
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

## Параметры

### Переменные окружения

Можно задать параметры через переменные окружения:

```bash
sudo GITHUB_USER=yourusername \
     GITHUB_REPO_NAME=proxy \
     BRANCH=main \
     bash -c "$(curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh)"
```

### Параметры:

- `GITHUB_USER` - имя пользователя или организации GitHub
- `GITHUB_REPO_NAME` - название репозитория
- `BRANCH` - ветка (по умолчанию: `main`)
- `INSTALL_DIR` - директория установки (по умолчанию: `/opt/proxy`)

## Интерактивный режим

Если параметры не указаны, скрипт запросит их интерактивно:

```bash
sudo bash install_from_github.sh
```

Скрипт спросит:
- GitHub username или organization
- Название репозитория
- Ветку (по умолчанию: main)

## Примеры использования

### Публичный репозиторий

```bash
# Простой способ
curl -fsSL https://raw.githubusercontent.com/yourusername/proxy/main/scripts/install_from_github.sh | sudo bash

# С параметрами
curl -fsSL https://raw.githubusercontent.com/yourusername/proxy/main/scripts/install_from_github.sh | \
  sudo GITHUB_USER=yourusername GITHUB_REPO_NAME=proxy bash
```

### Приватный репозиторий

Для приватного репозитория нужен токен доступа:

```bash
# Создать токен на GitHub: Settings -> Developer settings -> Personal access tokens
# Дать права: repo

# Использовать токен в URL
curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh | \
  sudo GITHUB_TOKEN=your_token bash
```

Или клонировать вручную:

```bash
# Клонировать с токеном
git clone https://YOUR_TOKEN@github.com/USERNAME/REPO.git /tmp/proxy
cd /tmp/proxy
sudo ./scripts/install.sh
```

### Другая ветка

```bash
curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh | \
  sudo BRANCH=develop bash
```

### Другая директория установки

```bash
curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh | \
  sudo INSTALL_DIR=/opt/my-proxy bash
```

## Что делает скрипт

1. ✅ Проверяет права root
2. ✅ Запрашивает данные репозитория (если не указаны)
3. ✅ Устанавливает git (если не установлен)
4. ✅ Клонирует репозиторий с GitHub
5. ✅ Копирует файлы в `/opt/proxy`
6. ✅ Запускает основной скрипт установки `install.sh`

## После установки

После успешной установки:

1. **Настройте безопасность:**
   ```bash
   sudo /opt/proxy/scripts/security.sh
   ```

2. **Настройте SSL:**
   ```bash
   sudo /opt/proxy/scripts/setup_ssl.sh your-domain.com
   ```

3. **Проверьте работу:**
   ```bash
   curl http://your-domain.com/health
   ```

## Устранение неполадок

### Ошибка: "Не удалось загрузить проект"

**Причины:**
- Неправильный URL репозитория
- Репозиторий приватный (нужен токен)
- Неправильное название ветки
- Нет доступа к интернету

**Решение:**
```bash
# Проверить доступность
curl -I https://github.com/USERNAME/REPO

# Проверить ветку
git ls-remote --heads https://github.com/USERNAME/REPO.git

# Клонировать вручную для проверки
git clone https://github.com/USERNAME/REPO.git /tmp/test
```

### Ошибка: "Не найден файл scripts/install.sh"

**Причина:** Структура репозитория отличается от ожидаемой.

**Решение:** Убедитесь, что в репозитории есть:
- `scripts/install.sh`
- `docker-compose.yml`
- `Dockerfile`
- Другие необходимые файлы

### Ошибка: "Permission denied"

**Решение:**
```bash
# Убедитесь, что запускаете с sudo
sudo bash install_from_github.sh

# Или
sudo curl -fsSL ... | bash
```

### Проблемы с приватным репозиторием

**Решение 1: Использовать токен**

```bash
# Создать токен на GitHub
# Settings -> Developer settings -> Personal access tokens -> Generate new token
# Выбрать scope: repo

# Использовать в URL
git clone https://YOUR_TOKEN@github.com/USERNAME/REPO.git
```

**Решение 2: Настроить SSH ключи**

```bash
# На сервере
ssh-keygen -t ed25519 -C "server@example.com"

# Добавить публичный ключ на GitHub
cat ~/.ssh/id_ed25519.pub
# Скопировать и добавить в GitHub: Settings -> SSH and GPG keys

# Клонировать через SSH
git clone git@github.com:USERNAME/REPO.git
```

## Безопасность

⚠️ **Важно:** При использовании скрипта напрямую с GitHub:

1. Убедитесь, что доверяете источнику
2. Проверьте содержимое скрипта перед запуском
3. Для продакшна лучше клонировать репозиторий вручную и проверить код

**Проверка скрипта перед запуском:**
```bash
# Загрузить и просмотреть
curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh > /tmp/script.sh
cat /tmp/script.sh
# Если все хорошо, запустить
sudo bash /tmp/script.sh
```

## Альтернативные методы

### Использование wget

```bash
wget -qO- https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh | sudo bash
```

### Загрузка архива

```bash
# Скачать архив
wget https://github.com/USERNAME/REPO/archive/main.zip
unzip main.zip
cd REPO-main

# Запустить установку
sudo ./scripts/install.sh
```

## Интеграция с CI/CD

Пример для GitHub Actions:

```yaml
- name: Install on server
  run: |
    curl -fsSL https://raw.githubusercontent.com/${{ github.repository }}/main/scripts/install_from_github.sh | \
      sudo GITHUB_USER=${{ github.repository_owner }} \
           GITHUB_REPO_NAME=${{ github.event.repository.name }} \
           bash
```

## Полезные ссылки

- [GitHub Raw Content](https://raw.githubusercontent.com/)
- [GitHub API](https://docs.github.com/en/rest)
- [Personal Access Tokens](https://github.com/settings/tokens)
