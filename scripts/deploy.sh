#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

# 1. Разбор аргумента --dry-run
DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
    echo "=== Режим пробного запуска (dry-run) ==="
fi

# 2. Проверка: файл site/index.html должен существовать (требование 4.a.iv)
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "ОШИБКА: файл ${LOCAL_DIR}index.html не найден. Доставка отменена." >&2
    exit 1
fi

# 3. Проверка: в репозитории не должно быть незафиксированных изменений (требование 4.a.v)
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ОШИБКА: в репозитории есть незафиксированные изменения. Доставка отменена." >&2
    exit 1
fi

# 4. Синхронизация каталога (требование 4.a.iii)
echo "=== Синхронизация ${LOCAL_DIR} -> ${REMOTE}:${REMOTE_DIR} ==="
rsync -avz --delete --chmod=D755,F644 \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    ${DRY_RUN} \
    "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# 5. При --dry-run завершаем с кодом 0 без проверки доступности (требование 4.a.i)
if [[ -n "${DRY_RUN}" ]]; then
    echo "=== Пробный запуск завершён ==="
    exit 0
fi

# 6. Проверка доступности ресурса (требование 4.a.vi)
echo "=== Проверка доступности ${SITE_URL} ==="
if ! curl -f --cacert "${CA_CERT}" -s -o /dev/null "${SITE_URL}"; then
    echo "ОШИБКА: ресурс ${SITE_URL} недоступен." >&2
    exit 1
fi

# 7. Успешное завершение — вывод хеша коммита (требование 4.a.vii)
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "=== Доставка завершена успешно. Коммит: ${COMMIT_HASH} ==="
exit 0