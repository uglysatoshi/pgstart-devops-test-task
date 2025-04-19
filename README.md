# Возникшая проблема
При создании виртуальной машины на CentOS у меня возникла проблема с несовместимостью моих комплектующих. 
В связи с этим я все же решил выполнить задание, но на двух машинах Debian Bookworm.

Снимок экрана возникшей ошибки
![image](https://github.com/user-attachments/assets/2e5a5f76-8432-4c20-9678-853820451f8e)
# Подготовка машин для выполнения скрипта
```
ssh-keygen -t rsa
ssh-copy-id root@remote_host1 # Отправка ключей на первую машину
ssh-copy-id root@remote_host2 # Отправка ключей на вторую машину
```
# Вызов скрипта
```
git clone https://github.com/uglysatoshi/pgstart-devops-test-task
cd pgstart-devops-test-task
chmod +x task-script.sh
./task-script.sh server1,server2
```

# Результаты выполнения скрипта
![image](https://github.com/user-attachments/assets/056ddbb4-2fd3-449a-9b35-0a56ebd9f868)

