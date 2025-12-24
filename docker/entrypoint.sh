#!/bin/bash
set -e

DB_PORT=${DB_PORT:-5432}
PATCH_DIR=Transport/versioningDb

# .pgpass
echo "$DB_HOST:$DB_PORT:$DB_NAME:$DB_USER:$DB_PASS" > /.pgpass
chmod 600 /.pgpass
export PGPASSFILE=/.pgpass

echo "=== DEBUG ==="
echo "DB_PASS='$DB_PASS'"
echo "Содержание PGPASS:"
cat /.pgpass
echo "права PGPASS (должны быть 600):"
ls -la /.pgpass
echo "=============="

if [[ "$SEED" == "true" ]]; then
  echo "=== Обнаружен флаг SEED=true, применение seed__adm_system_service_info.sql ==="
  PGPASSFILE=/.pgpass psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
      -v ON_ERROR_STOP=1 -f "Transport/_db/rnis/seed__adm_system_service_info.sql"
    echo "Seed seed__adm_system_service_info.sql ОК"
fi

# Получаем текущий патч из БД
LATEST=$(PGPASSFILE=/.pgpass psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
  -t -A -c "SELECT COALESCE(MAX(patch_number),0) FROM update_patch_history;" \
  2>/dev/null || echo 0)

LATEST_NUM=$((10#${LATEST:-0}))
echo "Текущий патч: $LATEST_NUM"

# === ОБРАБОТКА $VERSION ===
if [[ -n "${VERSION:-}" ]]; then
  echo "Указана версия: '$VERSION'"
  
  if [[ "$VERSION" == "latest" ]]; then
    echo "Режим 'latest' - обновление до последней версии"
    
  elif [[ "$VERSION" =~ ^[0-9]+$ ]]; then
    # Одно число, например "191"
    echo "Применение конкретной версии: $VERSION"
    
    PATCH_FILE="$PATCH_DIR/patch$VERSION.sql"
    if [[ -f "$PATCH_FILE" ]]; then
      if (( 10#$VERSION > LATEST_NUM )); then
        echo "=== Применение $PATCH_FILE ==="
        PGPASSFILE=/.pgpass psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
          -v ON_ERROR_STOP=1 -f "$PATCH_FILE"
        echo "Патч $VERSION ОК"
      else
        echo "Патч $VERSION уже применен (текущий: $LATEST_NUM)"
      fi
    else
      echo "Файл patch${VERSION}.sql не найден в $PATCH_DIR"
      exit 1
    fi
    exit 0
    
  else
    # Числа через запятую: "190,192,198"
    echo "Обработка списка версий: $VERSION"
    IFS=',' read -ra VERSIONS <<< "$VERSION"
    
    for ver in "${VERSIONS[@]}"; do
      ver=$(echo "$ver" | tr -d '[:space:]')  # убираем пробелы
      echo "Проверка версии: $ver"
      
      PATCH_FILE="$PATCH_DIR/patch${ver}.sql"
      if [[ -f "$PATCH_FILE" ]]; then
        if (( 10#$ver > LATEST_NUM )); then
          echo "=== Применение $PATCH_FILE ==="
          PGPASSFILE=/.pgpass psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
            -v ON_ERROR_STOP=1 -f "$PATCH_FILE"
          echo "Патч $ver ОК"
          
          # Обновляем LATEST после каждого патча
          LATEST=$(PGPASSFILE=/.pgpass psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
            -t -A -c "SELECT COALESCE(MAX(patch_number),0) FROM update_patch_history;" 2>/dev/null || echo 0)
          LATEST_NUM=$((10#${LATEST:-0}))
          echo "Новый текущий патч: $LATEST_NUM"
        else
          echo "Патч $ver уже применен (текущий: $LATEST_NUM)"
        fi
      else
        echo "Файл patch${ver}.sql не найден в $PATCH_DIR"
      fi
    done
    exit 0
  fi
fi

# === РЕЖИМ ПО УМОЛЧАНИЮ (latest) - применяем все новые патчи по порядку ===
echo "Применение всех доступных новых патчей..."
for patch in $(find "$PATCH_DIR" -name 'patch*.sql' -type f 2>/dev/null | sort -V); do
  base=$(basename "$patch" .sql)
  num=${base#patch}
  num=$((10#$num))

  if (( num > LATEST_NUM )); then
    echo "=== Применение $patch ==="
    PGPASSFILE=/.pgpass psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
      -v ON_ERROR_STOP=1 -f "$patch"
    echo "Патч $num ОК"
    
    # Обновляем LATEST после каждого патча
    LATEST=$(PGPASSFILE=/.pgpass psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" \
      -t -A -c "SELECT COALESCE(MAX(patch_number),0) FROM update_patch_history;" 2>/dev/null || echo 0)
    LATEST_NUM=$((10#${LATEST:-0}))
    echo "Новый текущий патч: $LATEST_NUM"
  fi
done

echo "Обновление завершено!"