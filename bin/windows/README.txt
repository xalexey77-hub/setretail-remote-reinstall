Windows NBD server is implemented as a standalone PowerShell script and CMD launcher.
No third-party NBD service is required.

Usage:
  start-nbd-server.cmd "C:\SetRetail\image.iso" 10810

The server exports the ISO READ ONLY and accepts one NBD client session.
Do not use Test-NetConnection against the waiting single-session server.
