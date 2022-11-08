#Doesn't work if past of notepad win10

Remove-Variable * -ErrorAction SilentlyContinue
$dir = "V:\My"
$DNSServer = $Env:DNSServer
$DHCPServer = $Env:DHCPServer
$ZoneName = "x5.ru"

#Ввести данные в скрипт. Ввод данных заканчивается при получении короткой строки (Нажать Enter дважды)


write-host "Enter Value (Enter and Enter to finish)"
while (1) {
    read-host | set r
    set test -value ($test + "`n" + $r)
    if ($r.Length -lt 3) { break }
}
cls

#Превращаем в удобоваримый вид, разделяя строки

$MessageToArray = $test.ToCharArray()
$MessageToArray = $test.split(" ")

$IPList = $MessageToArray|?{$_ -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"}|%{$Matches[0]}
foreach($IP in $IPList){
    Remove-DhcpServerv4Reservation -ComputerName $DHCPServer -IPAddress $IP
}
$Message = "Удалены резервации:
$IPList"
Set-Clipboard $Message
Write-Host -Object "$Message" -BackgroundColor Black -ForegroundColor Green
