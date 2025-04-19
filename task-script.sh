#!/bin/bash

# Проверка параметра
if [ -z "$1" ]; then
  echo "Использование: $0 <ip1,ip2,...>"
  exit 1
fi

# Конфигурация
USER="root"                              # Целевой пользователь
PRIVATE_KEY="~/.ssh/id_rsa"              # Путь к приватной части публичного ключа загруженного на сервера
SERVERS=$(echo "$1" | tr ',' ' ')        # Сервера полученные как аргументы при запуске скрипта
PG_PASSWORD="studentpass"                # Пароль для PostgreSQL
REMOTE_LOG="/root/remote_install.log"    # Путь к файлу логирования 
CHECK_LOG="/root/check_install.log"      # Путь к файлу логирования

declare -A LOADS

# Забираем нагрузку по серверу
echo "Оценка загрузки указанных серверов..."
for SERVER in $SERVERS; do
  echo "Проверка сервера $SERVER..."
  LOAD=$(ssh -i $PRIVATE_KEY -o StrictHostKeyChecking=no $USER@$SERVER \
    "uptime | awk -F'load average:' '{ print \$2 }' | cut -d',' -f1" 2>/dev/null)
  LOADS[$SERVER]=$LOAD
  echo "$SERVER: загрузка = $LOAD"
done

# Присваиваем переменным ip-адреса исходя из анализа нагрзуки
TARGET=$(for S in "${!LOADS[@]}"; do echo "${LOADS[$S]} $S"; done | sort -n | head -n1 | awk '{print $2}')
STUDENT_IP=$(for S in "${!LOADS[@]}"; do echo "${LOADS[$S]} $S"; done | sort -nr | head -n1 | awk '{print $2}')

# Выводим на экран результаты анализа нагрузки
echo "Результаты анализа:"
echo "Целевой сервер для установки PostgreSQL: $TARGET"
echo "Сервер, с которого будет разрешено подключение: $STUDENT_IP"

# Установка PostgreSQL и настройка (логируются только apt, тк вывод команды довольно массивный)
REMOTE_SCRIPT=$(cat <<EOF
echo "Установка и настройка PostgreSQL"
if ! id postgres >/dev/null 2>&1; then
  echo "Установка PostgreSQL (лог: $REMOTE_LOG)..."
  apt update >> $REMOTE_LOG 2>&1
  apt install -y postgresql >> $REMOTE_LOG 2>&1
else
  echo "PostgreSQL уже установлен"
fi

echo "Настройка PostgreSQL для внешних подключений"
PG_CONF=\$(find /etc/postgresql/ -name postgresql.conf | head -n 1)
HBA_CONF=\$(find /etc/postgresql/ -name pg_hba.conf | head -n 1)
if [ -n "\$PG_CONF" ]; then
  sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" "\$PG_CONF"
fi
if [ -n "\$HBA_CONF" ]; then
  echo "host all student $STUDENT_IP/32 md5" >> "\$HBA_CONF"
fi
systemctl restart postgresql

echo "Создание пользователя student, если не существует..."
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='student'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE ROLE student WITH LOGIN PASSWORD '$PG_PASSWORD';"

echo "Создание базы данных student, если не существует..."
sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw student || \
  sudo -u postgres createdb -O student student

echo "Проверка: SELECT 1 от имени postgres"
sudo -u postgres psql -c "SELECT 1;"
EOF
)

echo "Подключение к $TARGET и установка PostgreSQL..."
ssh -i $PRIVATE_KEY -o StrictHostKeyChecking=no $USER@$TARGET "$REMOTE_SCRIPT"
echo "Установка и настройка завершены"

# Проверка подключения с другого сервера (логируются только apt, тк вывод команды довольно массивный)
CHECK_REMOTE=$(cat <<EOF
echo "Проверка подключения пользователя student к БД на $TARGET"

echo "Установка postgresql-client (лог: $CHECK_LOG)..."
apt update >> $CHECK_LOG 2>&1
apt install -y postgresql-client >> $CHECK_LOG 2>&1

echo "Создание временного pgpass файла..."
PGPASS_FILE="/tmp/.pgpass_student_test"
echo "$TARGET:5432:student:student:$PG_PASSWORD" > \$PGPASS_FILE
chmod 600 \$PGPASS_FILE

echo "Подключение к БД и выполнение SELECT 1..."
PGPASSFILE=\$PGPASS_FILE psql -U student -h $TARGET -d student -c "SELECT 1;" && \
  echo "Подключение выполнено успешно" || \
  echo "Ошибка подключения к БД как student"

rm -f \$PGPASS_FILE
EOF
)

echo "Проверка подключения с $STUDENT_IP к БД на $TARGET..."
ssh -i $PRIVATE_KEY -o StrictHostKeyChecking=no $USER@$STUDENT_IP "$CHECK_REMOTE"
echo ""
echo "Сценарий завершён."
