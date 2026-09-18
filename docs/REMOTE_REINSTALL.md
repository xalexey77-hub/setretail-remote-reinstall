# Полная процедура удаленной переустановки

## 1. Архитектура

Windows NBD server отдает установочный ISO только на чтение. TinyCore/SetRetail installer на кассе получает адрес сервера через kernel cmdline, подключает export как `/dev/nbd0`, монтирует ISO и загружает TCE из `/mnt/nbd0/boot/tce`.

Переменные: `KSO_IP`, `NBD_SERVER_IP`, `NBD_PORT` (обычно 10810), `ISO_PATH`, `PREFLIGHT_PORT` (обычно 10022).

## 2. NBD server

Запуск на Windows:

```bat
bin\windows\start-nbd-server.cmd "C:\SetRetail\image.iso" 10810
```

Firewall: разрешить входящий TCP NBD_PORT только от KSO_IP. Дождаться `Waiting for NBD client...`. Не использовать `Test-NetConnection` к односессионному серверу.

## 3. NBD client в initramfs

Из ISO монтируется оригинальный `boot/core.gz`. Готовый/собранный Linux client помещается в `usr/sbin/nbd-client` через `scripts/build-nbd-initramfs.sh`. После упаковки скрипт повторно распаковывает initramfs и проверяет, что `/usr/bin/sudo` не потерян.

## 4. GRUB и NBD-сессия

Kernel cmdline:

```text
tce=nbd0/boot/tce nbd=<NBD_SERVER_IP>:<NBD_PORT>:no-ping
```

Штатный `tc-config` запускает NBD client, подключает `/dev/nbd0` и монтирует ISO в `/mnt/nbd0`.

## 5. SAFE PREFLIGHT

Создать preflight initramfs и GRUB entries:

```bash
sudo ./scripts/build-preflight-initramfs.sh /boot/setretail-core-nbd-v3.gz /boot/setretail-core-preflight-v3.gz 10022
sudo ./scripts/create-grub-entries.sh <NBD_SERVER_IP> <NBD_PORT>
grub-reboot setretail-nbd-preflight-v3
sync
reboot
```

Проверить `/proc/cmdline`, `sudo -V`, `TCEDIR`, mount `/dev/nbd0`, `tce-status -i`, реальные `/tmp/tcloop` mounts, `lsblk`, `fdisk`; убедиться, что нет `install.sh/parted/sfdisk/mkfs/wipefs`. Рекомендуется полный `md5sum -c install.md5`.

## 6. INSTALL

INSTALL entry не должен содержать `norestore`, иначе штатный `mydata.tgz` не восстановится и `install.sh` не запустится.

Перед reboot:

```bash
grub-reboot setretail-nbd-install-v3
grub-editenv /boot/grub/grubenv list
```

Убедиться, что `next_entry=setretail-nbd-install-v3`, затем `sync; reboot`.

**INSTALL может полностью уничтожить текущую разметку локального диска.**

## 7. Завершение NBD

Паузы между READ нормальны. После появления мастера новой SetRetail NBD-сессия может остаться открытой, если installer не отправил `NBD_CMD_DISC`. После подтвержденной загрузки новой системы сервер можно завершить `Ctrl+C`.
