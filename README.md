# SetRetail Remote Reinstall via NBD

Комплект для удаленной переустановки кассы/КСО SetRetail без физической USB-флешки.

> **WARNING:** режим INSTALL может полностью переразметить и отформатировать локальный диск кассы. Для новой модели кассы или новой версии ISO сначала выполняйте SAFE PREFLIGHT.

## Схема

`Windows NBD server -> TCP/NBD -> TinyCore installer on KSO -> /dev/nbd0 -> ISO -> vendor install.sh -> local SSD`

Параметры не зашиты в комплект:

- `KSO_IP` - IP кассы;
- `NBD_SERVER_IP` - IPv4 компьютера, который отдает ISO;
- `NBD_PORT` - TCP-порт, по умолчанию `10810`;
- `ISO_PATH` - путь к установочному ISO;
- `PREFLIGHT_PORT` - диагностический shell, по умолчанию `10022`.

## Готовые компоненты

- `bin/linux-x86_64/nbd-client-2048-ipv4` - проверенный статический x86-64 Linux NBD client (IPv4, block size 2048). SHA256: `36e8ea733ef5d01aacba839b048ae656a58ea27ca7249450420b2dd47f43f36a`.
- `bin/windows/nbd-server.ps1` - read-only NBD server для Windows PowerShell.
- `bin/windows/start-nbd-server.cmd` - launcher.
- `scripts/` - сборка initramfs, SAFE PREFLIGHT, GRUB и аудит.
- `docs/` - полная инструкция DOCX/PDF.

## Пошаговая инструкция для первой установки

Если вы раньше не выполняли такую переустановку, используйте подробную инструкцию:

**[docs/REMOTE_REINSTALL.md](docs/REMOTE_REINSTALL.md)**

Она ведёт оператора от проверки IP и Windows Firewall до SAFE PREFLIGHT, проверки ISO, одноразового GRUB boot, реальной установки и действий после первого запуска.

Не начинайте сразу с INSTALL: сначала полностью пройдите SAFE PREFLIGHT.

## Настройка NBD-сессии

### Windows: export ISO

```powershell
.\bin\windows\start-nbd-server.cmd "C:\SetRetail\image.iso" 10810
```

Дождитесь `Waiting for NBD client...`. Разрешите входящий TCP `NBD_PORT` в Windows Firewall только от `KSO_IP`. Не используйте `Test-NetConnection`/TCP probe: сервер односессионный.

### Linux installer: NBD client

```bash
sudo ./scripts/build-nbd-initramfs.sh \
  /mnt/setretail-iso/boot/core.gz \
  ./bin/linux-x86_64/nbd-client-2048-ipv4 \
  /boot/setretail-core-nbd-v3.gz
```

GRUB передает:

```text
tce=nbd0/boot/tce nbd=<NBD_SERVER_IP>:<NBD_PORT>:no-ping
```

Штатный `tc-config` подключает export к `/dev/nbd0` и монтирует его в `/mnt/nbd0`.

### SAFE PREFLIGHT

Проверить `/proc/cmdline`, `mount | grep nbd0`, `readlink /etc/sysconfig/tcedir`, `tce-status -i`, `lsblk`. Локальный SSD должен однозначно отличаться от NBD ISO.

### Завершение сессии

Установщик может не отправить `NBD_CMD_DISC`. После подтвержденной загрузки новой SetRetail и появления мастера первоначальной настройки NBD server можно завершить `Ctrl+C`. Пауза между `READ` сама по себе не означает зависание.

## Что не публикуется

ISO SetRetail, vendor payload, лицензии, ключи и конфигурация конкретной кассы в репозиторий не включаются.
