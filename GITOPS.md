# GitOps Workflow Guide

Этот репозиторий настроен для работы по принципу GitOps - все изменения инфраструктуры происходят через Git commits.

## 🌐 Работа через веб-редактор GitHub

### Изменение конфигурации сервисов

**Сценарий: Изменить количество реплик Nginx**

1. Перейдите на GitHub: `stacks/app/docker-compose.yml`
2. Нажмите кнопку "Edit" (карандаш)
3. Найдите секцию nginx:
```yaml
nginx:
  deploy:
    replicas: 2  # ← Измените это значение
```
4. Измените на `replicas: 3`
5. Внизу страницы: "Commit changes"
6. Опишите изменение: `Scale nginx to 3 replicas`
7. Нажмите "Commit changes"
8. ✅ GitHub Actions автоматически задеплоит изменения!

### Добавление нового сервиса

**Сценарий: Добавить Redis в стек app**

1. Откройте `stacks/app/docker-compose.yml`
2. Добавьте в секцию `services`:
```yaml
  redis:
    image: redis:alpine
    networks:
      - app-network
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
```
3. Commit → автоматический деплой!

### Изменение домена

**Сценарий: Изменить домен для Nginx**

1. **Вариант A: Незашифрованное изменение** (если домен в docker-compose.yml)
   - Редактируйте `stacks/app/docker-compose.yml` через веб
   
2. **Вариант B: Зашифрованное изменение** (если домен в .env.encrypted)
   - Локально: `sops stacks/app/.env.encrypted`
   - Измените `NGINX_DOMAIN=new-domain.com`
   - Сохраните и закройте
   - `git push` → автоматический деплой

## 🔄 Что происходит при commit

1. **GitHub Actions обнаруживает изменения** в директории `stacks/`
2. **Определяет какой стек изменился** (traefik или app)
3. **Расшифровывает секреты** через SOPS_AGE_KEY
4. **Подключается к серверу** через SSH (из .ssh.encrypted)
5. **Деплоит только изменённый стек** через Docker Swarm
6. **Отправляет уведомление** в чат (если настроено)

## 📋 Типичные GitOps операции

### Обновление версии образа

```yaml
# В stacks/app/docker-compose.yml
postgres:
  image: postgres:16-alpine  # Было: postgres:15-alpine
```
Commit → автоматическое обновление до PostgreSQL 16

### Изменение лимитов ресурсов

```yaml
# В stacks/app/docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```
Commit → применение новых лимитов

### Добавление переменной окружения

```yaml
# В stacks/app/docker-compose.yml
postgres:
  environment:
    POSTGRES_DB: ${POSTGRES_DB}
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_MAX_CONNECTIONS: 200  # ← Новая переменная
```
Commit → перезапуск с новой конфигурацией

## 🔐 Работа с секретами

### Локальное редактирование секретов

Секреты нужно редактировать локально с помощью SOPS:

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/username/repo.git
cd repo

# 2. Настройте SOPS Age ключ
echo "AGE-SECRET-KEY-1xxx..." > ~/.config/sops/age/keys.txt

# 3. Отредактируйте секреты
sops stacks/app/.env.encrypted

# 4. Сохраните и отправьте
git add stacks/app/.env.encrypted
git commit -m "Update database password"
git push  # → Автоматический деплой!
```

### Быстрое изменение пароля БД

```bash
# Редактирование
sops stacks/app/.env.encrypted
# Измените POSTGRES_PASSWORD=new_secure_password_123

# Push
git add stacks/app/.env.encrypted
git commit -m "Rotate database password"
git push
```

## 🚀 Ручной запуск деплоя

Если нужно задеплоить все стеки:

1. Перейдите на GitHub: **Actions** → **Deploy to Docker Swarm**
2. Нажмите **"Run workflow"**
3. Выберите ветку: `main`
4. Нажмите **"Run workflow"**
5. ✅ Все стеки будут задеплоены

## 📊 Мониторинг деплоя

1. Перейдите в **Actions** на GitHub
2. Откройте последний workflow run
3. Смотрите логи деплоя в реальном времени
4. Проверьте статус: ✅ Success или ❌ Failed

## 🔔 Уведомления (опционально)

Добавьте в конец `.github/workflows/deploy.yml`:

```yaml
- name: Notify on success
  if: success()
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -H 'Content-Type: application/json' \
      -d '{"text":"✅ Stack ${{ matrix.stack }} deployed successfully!"}'

- name: Notify on failure
  if: failure()
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -H 'Content-Type: application/json' \
      -d '{"text":"❌ Stack ${{ matrix.stack }} deployment failed!"}'
```

## 🎯 Best Practices

1. **Описывайте изменения в commit messages**
   - ✅ `Scale nginx to 3 replicas for better load distribution`
   - ❌ `update`

2. **Делайте маленькие атомарные изменения**
   - Одно изменение = один commit
   - Проще откатить при проблемах

3. **Тестируйте локально перед push**
   ```bash
   docker-compose -f stacks/app/docker-compose.yml config
   ```

4. **Используйте branches для экспериментов**
   ```bash
   git checkout -b test-redis
   # Внесите изменения
   git push origin test-redis
   # Создайте Pull Request для review
   ```

5. **Мониторьте логи после деплоя**
   - Проверяйте Actions на GitHub
   - Смотрите логи на сервере: `docker service logs -f app_nginx`

## 🔄 Откат изменений

Если что-то пошло не так:

```bash
# Вариант 1: Через веб
# GitHub → History → найдите предыдущий коммит → "Revert"

# Вариант 2: Локально
git revert HEAD
git push  # → Автоматический откат!

# Вариант 3: Полный откат
git reset --hard HEAD~1
git push --force  # Осторожно!
```

## 📚 Полезные ссылки

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [Docker Stack Documentation](https://docs.docker.com/engine/swarm/stack-deploy/)
- [SOPS Documentation](https://github.com/mozilla/sops)
- [GitOps Principles](https://www.gitops.tech/)
