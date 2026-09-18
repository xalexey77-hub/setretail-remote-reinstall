param(
 [Parameter(Mandatory=$true)][string]$Image,
 [int]$Port=10810,
 [string]$ListenAddress="0.0.0.0"
)
$ErrorActionPreference="Stop"
if(-not (Test-Path -LiteralPath $Image)){throw "ISO not found: $Image"}
$Image=(Resolve-Path -LiteralPath $Image).Path
$Size=(Get-Item -LiteralPath $Image).Length
function BE32([uint32]$v){[byte[]]@(($v-shr 24)-band 255,($v-shr 16)-band 255,($v-shr 8)-band 255,$v-band 255)}
function BE64([uint64]$v){[byte[]]@(($v-shr 56)-band 255,($v-shr 48)-band 255,($v-shr 40)-band 255,($v-shr 32)-band 255,($v-shr 24)-band 255,($v-shr 16)-band 255,($v-shr 8)-band 255,$v-band 255)}
function U32([byte[]]$b,[int]$o){[uint32](($b[$o]-shl 24)-bor($b[$o+1]-shl 16)-bor($b[$o+2]-shl 8)-bor$b[$o+3])}
function U64([byte[]]$b,[int]$o){[uint64]$v=0;for($i=0;$i-lt 8;$i++){$v=($v-shl 8)-bor[uint64]$b[$o+$i]};$v}
function RX($s,[int]$n){$b=New-Object byte[] $n;$p=0;while($p-lt$n){$r=$s.Read($b,$p,$n-$p);if($r-le 0){throw "Client disconnected."};$p+=$r};$b}
$L=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Parse($ListenAddress),$Port);$L.Start()
Write-Host "SetRetail temporary NBD server";Write-Host "Image : $Image";Write-Host "Size  : $Size bytes";Write-Host "Port  : $Port";Write-Host "Mode  : READ ONLY";Write-Host "`nWaiting for NBD client..."
try{
 $C=$L.AcceptTcpClient();$S=$C.GetStream();Write-Host "Client connected: $($C.Client.RemoteEndPoint)"
 $m=[Text.Encoding]::ASCII.GetBytes("NBDMAGIC");$S.Write($m,0,8)
 $x=BE64 0x0000420281861253;$S.Write($x,0,8);$x=BE64 ([uint64]$Size);$S.Write($x,0,8)
 $x=BE32 1;$S.Write($x,0,4);$z=New-Object byte[] 124;$S.Write($z,0,124);$S.Flush()
 $F=[IO.File]::Open($Image,'Open','Read','Read')
 while($true){
  $q=RX $S 28;if((U32 $q 0)-ne 0x25609513){throw "Invalid NBD request"}
  $t=U32 $q 4;$h=$q[8..15];$o=U64 $q 16;$n=U32 $q 24
  if($t-eq 2){break}
  if($t-ne 0){$r=(BE32 0x67446698)+(BE32 1)+$h;$S.Write($r,0,$r.Length);$S.Flush();continue}
  if(($o+$n)-gt[uint64]$Size){throw "Read beyond image"}
  $r=(BE32 0x67446698)+(BE32 0)+$h;$S.Write($r,0,$r.Length);$F.Position=[int64]$o
  $left=[int]$n;$buf=New-Object byte[] ([Math]::Min(1048576,[Math]::Max(4096,$left)))
  while($left-gt 0){$want=[Math]::Min($buf.Length,$left);$got=$F.Read($buf,0,$want);if($got-le 0){throw "EOF"};$S.Write($buf,0,$got);$left-=$got}
  $S.Flush();Write-Host "READ offset=$o length=$n"
 }
}catch{Write-Host "NBD SERVER ERROR:";Write-Host $_.Exception.Message}
finally{if($F){$F.Dispose()};if($C){$C.Close()};$L.Stop();Write-Host "NBD server stopped."}
