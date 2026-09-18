# Удалённая переустановка SetRetail/КСО через NBD — пошаговая инструкция

Эта инструкция рассчитана на человека, который **никогда раньше не выполнял удалённую установку кассы**. Не переходите к следующему этапу, пока результат текущего этапа не совпадает с ожидаемым.

> **ОПАСНО:** этап INSTALL запускает штатный установщик SetRetail и может полностью удалить существующую разметку и данные локального диска кассы. SAFE PREFLIGHT выполняется первым.

## 0. Что мы делаем

В магазине есть два компьютера:

1. **Касса/КСО** — Linux-машина, которую нужно переустановить. К ней должен быть SSH-доступ до начала установки.
2. **NBD-сервер** — Windows ПК, доступный кассе по сети. На нём лежит ISO SetRetail.

Схема:

```text
ISO на Windows
      |
      | NBD / TCP 10810
      v
касса -> /dev/nbd0 -> ISO SetRetail -> install.sh -> локальный SSD
```

Пример из успешно выполненной установки:

```text
KSO_IP         = 10.10.14.64
NBD_SERVER_IP  = 10.10.14.139
NBD_PORT       = 10810
PREFLIGHT_PORT = 10022
```

**Не копируйте эти IP вслепую.** Подставьте адреса своей кассы и своего Windows ПК.

---

## 1. Что подготовить заранее

Нужно иметь:

- установочный ISO SetRetail;
- Windows ПК, который останется включённым на всё время установки;
- SSH-доступ к текущей Linux-системе кассы;
- этот репозиторий;
- проверенный статический Linux `bin/linux-x86_64/nbd-client-2048-ipv4`;
- возможность перезагрузить кассу удалённо.

До форматирования отдельно сохраните всё, что нельзя получить заново: индивидуальные сертификаты, VPN-конфигурацию, нестандартные сетевые настройки и локальные данные. В проверенной инфраструктуре, например, OpenVPN использовал `/etc/sysconfig/config-ovpn0` и сертификаты в `/opt/networks/certs/`.

### Запишите свои параметры

```text
KSO_IP=
NBD_SERVER_IP=
NBD_PORT=10810
ISO_PATH=
PREFLIGHT_PORT=10022
```

---

## Важно: команды на Windows выполняются в PowerShell

Все команды этой инструкции, которые относятся к Windows-машине, нужно выполнять в **Windows PowerShell**. Если для конкретного шага требуются права администратора, запускайте PowerShell через **«Запуск от имени администратора»**.

Команды для кассы выполняются отдельно — в Linux shell через SSH.

## 2. Проверить связь между кассой и Windows

На кассе:

```bash
ip -br addr
ip route
ping -c 3 <NBD_SERVER_IP>
```

Ожидается ответ ping. Если касса не видит NBD-сервер, **установку не начинаем**.

На Windows откройте **PowerShell** и узнайте IP:

```powershell
ipconfig
```

Убедитесь, что используете адрес сетевого интерфейса, доступного именно кассе.

---

## 3. Подготовить ISO на Windows

Например:

```text
C:\SetRetail\SR-10.x.x.iso
```

ISO не нужно распаковывать на Windows.

Скопируйте из репозитория каталог:

```text
bin\windows\
```

В нём находятся:

```text
nbd-server.ps1
start-nbd-server.cmd
```

---

## 4. Разрешить NBD в Windows Firewall

NBD использует TCP. По умолчанию в инструкции — порт `10810`.

PowerShell от администратора:

```powershell
New-NetFirewallRule `
  -DisplayName "SetRetail NBD 10810" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 10810 `
  -RemoteAddress <KSO_IP> `
  -Action Allow
```

Если выбран другой NBD_PORT, замените `10810`.

Это правило лучше ограничивать IP конкретной кассы.

---

## 5. Запустить NBD-сервер

На Windows откройте **PowerShell** в каталоге репозитория:

```powershell
.\bin\windows\start-nbd-server.cmd "C:\SetRetail\SR-10.x.x.iso" 10810
```

Ожидаем:

```text
Image : C:\SetRetail\SR-10.x.x.iso
Size  : ... bytes
Port  : 10810
Mode  : READ ONLY

Waiting for NBD client...
```

### Важно

**Не запускайте `Test-NetConnection <server> -Port 10810` и другие TCP probes.**

Наш NBD server односессионный. Обычная проверка TCP-порта может подключиться вместо настоящего NBD-клиента.

Окно NBD оставляем открытым.

---

## 6. Подготовить файлы установщика на кассе

ISO должен быть доступен и на текущей Linux-системе кассы для извлечения оригинальных `vmlinuz` и `core.gz`. Если ISO уже скопирован на кассу:

```bash
sudo -i
mkdir -p /mnt/setretail-iso
mount -o loop,ro /path/to/SetRetail.iso /mnt/setretail-iso
ls -l /mnt/setretail-iso/boot/
```

Скопировать ядро:

```bash
cp /mnt/setretail-iso/boot/vmlinuz /boot/setretail-vmlinuz
```

Проверьте:

```bash
ls -lh /boot/setretail-vmlinuz
sha256sum /boot/setretail-vmlinuz
```

Хеш запишите в журнал установки.

---

## 7. Собрать NBD initramfs

Используем **оригинальный `core.gz` именно от устанавливаемого ISO** и проверенный бинарник `nbd-client-2048-ipv4` из репозитория.

Перед сборкой обязательно проверяем бинарник:

```bash
sha256sum ./bin/linux-x86_64/nbd-client-2048-ipv4
```

Ожидаемый SHA256:

```text
36e8ea733ef5d01aacba839b048ae656a58ea27ca7249450420b2dd47f43f36a  ./bin/linux-x86_64/nbd-client-2048-ipv4
```

Если хеш отличается — **не продолжайте установку**.

```bash
sudo ./scripts/build-nbd-initramfs.sh \
  /mnt/setretail-iso/boot/core.gz \
  ./bin/linux-x86_64/nbd-client-2048-ipv4 \
  /boot/setretail-core-nbd-v3.gz
```

Скрипт:

1. распакует оригинальный `core.gz`;
2. проверит наличие `/usr/bin/sudo`;
3. добавит `nbd-client`;
4. заново упакует initramfs;
5. распакует готовый файл повторно;
6. проверит, что `sudo` не потерян.

После сборки:

```bash
./scripts/audit-initramfs.sh /boot/setretail-core-nbd-v3.gz
sha256sum /boot/setretail-core-nbd-v3.gz
```

Если audit завершается ошибкой — **дальше не идём**.

---

## 8. Создать SAFE PREFLIGHT initramfs

SAFE PREFLIGHT загружает тот же installer environment, но не должен запускать реальную установку.

```bash
sudo ./scripts/build-preflight-initramfs.sh \
  /boot/setretail-core-nbd-v3.gz \
  /boot/setretail-core-preflight-v3.gz \
  10022
```

Проверить:

```bash
gzip -t /boot/setretail-core-preflight-v3.gz
sha256sum /boot/setretail-core-preflight-v3.gz
```

---

## 9. Создать GRUB entries

Подставляем **IP NBD-сервера**, а не IP кассы:

```bash
sudo ./scripts/create-grub-entries.sh <NBD_SERVER_IP> 10810
```

Например:

```bash
sudo ./scripts/create-grub-entries.sh 10.10.14.139 10810
```

Скрипт создаёт две записи:

```text
setretail-nbd-preflight-v3
setretail-nbd-install-v3
```

Проверить:

```bash
grep -n -A4 -B2 "SetRetail NBD" /boot/grub/grub.cfg
```

### PREFLIGHT должен содержать

```text
setmode=preflight
tce=nbd0/boot/tce
nbd=<NBD_SERVER_IP>:<NBD_PORT>:no-ping
norestore
noswap
```

### INSTALL должен содержать

```text
setmode=install
tce=nbd0/boot/tce
nbd=<NBD_SERVER_IP>:<NBD_PORT>:no-ping
```

**INSTALL не должен содержать `norestore`.**

---

## 10. Проверить безопасный возврат GRUB

Перед preflight:

```bash
grep '^GRUB_DEFAULT' /etc/default/grub
grub-editenv /boot/grub/grubenv list
```

Для нашей схемы используется `GRUB_DEFAULT=saved`. `saved_entry` должен указывать на рабочую текущую Ubuntu.

Запускаем **только preflight**:

```bash
grub-reboot setretail-nbd-preflight-v3
echo "GRUB_REBOOT_RC=$?"
grub-editenv /boot/grub/grubenv list
```

Ожидается:

```text
GRUB_REBOOT_RC=0
next_entry=setretail-nbd-preflight-v3
```

После этого:

```bash
sync
reboot
```

---

## 11. Что должно произойти после PREFLIGHT reboot

В окне Windows NBD:

```text
Client connected: ...
READ offset=...
READ offset=...
...
```

Это означает, что касса:

1. загрузила installer kernel/initramfs;
2. подключилась к Windows;
3. увидела ISO как NBD block device.

Если `Client connected` не появляется — не переходите к INSTALL.

---

## 12. Подключиться к SAFE PREFLIGHT shell

На Windows откройте **PowerShell**:

```powershell
.\scripts\preflight-client.ps1 -KsoIp <KSO_IP> -Port 10022
```

После подключения:

```powershell
Send-Cmd 'id; cat /proc/cmdline'
```

Ожидаем `uid=0(root)` и правильные параметры `nbd=...`, `setmode=preflight`, `norestore`.

Далее:

```powershell
Send-Cmd 'sudo -V | head'
Send-Cmd 'readlink /etc/sysconfig/tcedir'
Send-Cmd 'mount | grep nbd0'
Send-Cmd 'tce-status -i'
Send-Cmd 'mount | grep /tmp/tcloop'
Send-Cmd 'which lsblk; which fdisk'
Send-Cmd 'lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT'
```

Ожидается:

- `/dev/nbd0` соответствует размеру ISO и смонтирован read-only;
- TCEDIR = `/mnt/nbd0/boot/tce`;
- `sudo` работает;
- загружены `util-linux`, `ncurses`, `readline` и зависимости;
- `lsblk` и `fdisk` существуют;
- локальный SSD и NBD ISO невозможно перепутать.

Проверить отсутствие разрушительных процессов:

```powershell
Send-Cmd "ps | grep -E 'install.sh|parted|sfdisk|mkfs|wipefs' | grep -v grep"
```

В SAFE PREFLIGHT их быть не должно.

---

## 13. Проверить установочный ISO

Из preflight shell перейдите в корень смонтированного ISO и выполните штатную проверку:

```sh
cd "$(readlink /etc/sysconfig/tcedir)/../../"
md5sum -c install.md5
echo "MEDIA_RC=$?"
```

Нужно получить:

```text
MEDIA_RC=0
```

и ни одной строки `FAILED`.

Если MD5 не проходит — INSTALL не запускаем.

---

## 14. Вернуться в старую Ubuntu

Перезагрузите кассу из preflight.

Поскольку использовался `grub-reboot`, одноразовая запись должна быть израсходована и касса должна вернуться в прежнюю Ubuntu.

После SSH-подключения:

```bash
uname -a
findmnt /
sudo grub-editenv /boot/grub/grubenv list
```

Ожидается:

```text
/ -> локальный старый root filesystem
next_entry=
```

Если `next_entry` не пуст — остановитесь и выясните причину.

---

## 15. Последняя проверка перед реальной установкой

На кассе:

```bash
sha256sum /boot/setretail-vmlinuz /boot/setretail-core-nbd-v3.gz

grep -A3 \
  "menuentry 'SetRetail NBD Remote Install V3'" \
  /boot/grub/grub.cfg

grub-editenv /boot/grub/grubenv list
```

Проверяем:

- правильный kernel;
- правильный NBD initramfs;
- правильный NBD_SERVER_IP;
- правильный NBD_PORT;
- `setmode=install`;
- **нет `norestore`**;
- `next_entry` пока пуст.

На Windows перезапустите NBD server, если предыдущая сессия завершилась, и снова дождитесь:

```text
Waiting for NBD client...
```

---

## 16. Вооружить одноразовую INSTALL-загрузку

**Эта команда ещё не форматирует диск.**

```bash
sudo grub-reboot setretail-nbd-install-v3
echo "GRUB_REBOOT_RC=$?"
sudo grub-editenv /boot/grub/grubenv list
```

Ожидается:

```text
GRUB_REBOOT_RC=0
next_entry=setretail-nbd-install-v3
```

Если значение другое — **не reboot**.

---

## 17. Запустить реальную установку

Это последняя точка, после которой текущая ОС может быть уничтожена:

```bash
sync
reboot
```

SSH пропадёт — это нормально.

Следите за окном NBD на Windows. Должны появиться:

```text
Client connected
READ offset=...
...
```

Установщик сначала читает компоненты TinyCore/TCE, проверяет media, затем работает с локальным SSD и payload.

### Не пугайтесь пауз

Несколько минут без новых `READ` могут означать распаковку архива или запись на SSD. **Не перезагружайте кассу только из-за паузы NBD.**

---

## 18. Как понять, что установка закончилась

Основной критерий — касса загрузилась уже в новую систему SetRetail и появился штатный интерфейс/мастер первоначальной настройки.

NBD-сессия при этом **может остаться открытой**. Это наблюдалось на реально выполненной установке: installer не отправил `NBD_CMD_DISC`, хотя новая система уже успешно загрузилась.

После подтверждения загрузки новой SetRetail NBD server можно завершить:

```text
Ctrl+C
```

Не закрывайте NBD раньше только потому, что прекратились READ.

---

## 19. После установки

Проверьте:

```bash
ip -br addr
ip route
```

Затем восстановите инфраструктурные настройки, которые не входят в чистый SetRetail ISO: VPN, индивидуальные сертификаты, маршруты и т.п.

Если используется локальный OpenVPN, до переустановки следует сохранить его индивидуальные credentials. Не копируйте приватный ключ с соседней кассы, если сертификаты выдаются на устройство индивидуально.

---

## 20. Краткий чек-лист оператора

Перед **PREFLIGHT**:

- касса отвечает по SSH;
- касса видит NBD_SERVER_IP;
- ISO выбран правильно;
- Windows NBD показывает READ ONLY / Waiting for NBD client;
- kernel/core.gz взяты из нужного ISO;
- audit initramfs успешен;
- GRUB preflight содержит `norestore noswap`.

Перед **INSTALL**:

- SAFE PREFLIGHT полностью прошёл;
- ISO MD5 = OK;
- локальный SSD однозначно определён;
- касса вернулась в старую Ubuntu;
- `next_entry` пуст;
- install entry содержит правильный IP/порт;
- install entry **не содержит norestore**;
- NBD server снова ожидает клиента;
- необходимые VPN/cert/config данные сохранены.

Только после этого выполняются `grub-reboot setretail-nbd-install-v3` и `reboot`.

---

## 21. Типовые ошибки

| Симптом | Что проверять |
|---|---|
| NBD не получает Client connected | IP сервера, firewall, маршрутизацию, состояние Waiting for NBD client |
| NBD server неожиданно занят | Не выполнялся ли Test-NetConnection/TCP probe |
| В preflight нет sudo | initramfs собран неправильно; повторить build/audit |
| Нет lsblk/fdisk | проверить sudo, tce-status и mounts util-linux/ncurses |
| fdisk ругается на libtinfo | не загрузился ncurses TCE |
| После preflight загрузилась старая Ubuntu | это нормальное поведение grub-reboot |
| INSTALL не стартует | проверить отсутствие norestore и восстановление штатного mydata.tgz |
| NBD долго не показывает READ | возможна локальная распаковка/запись SSD; не reboot вслепую |
| После установки нет доступа к серверной сети | восстановить VPN/сертификаты/маршруты, если они не входят в ISO |

