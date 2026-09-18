param([Parameter(Mandatory=$true)][string]$KsoIp,[int]$Port=10022)
$client=New-Object System.Net.Sockets.TcpClient;$client.Connect($KsoIp,$Port)
$stream=$client.GetStream();$stream.ReadTimeout=1000;$enc=New-Object System.Text.ASCIIEncoding
function Send-Cmd($cmd){
 Write-Host "`n>>> $cmd";$d=$enc.GetBytes($cmd+"`n");$stream.Write($d,0,$d.Length);$stream.Flush()
 Start-Sleep -Milliseconds 300;$b=New-Object byte[] 8192;$o=""
 while($stream.DataAvailable){$n=$stream.Read($b,0,$b.Length);if($n-le 0){break};$o+=$enc.GetString($b,0,$n);Start-Sleep -Milliseconds 100}
 Write-Host $o
}
Write-Host "Connected. Example: Send-Cmd 'id; cat /proc/cmdline'"
