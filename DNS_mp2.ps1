Remove-Variable * -ErrorAction SilentlyContinue

$DNSServer = $Env:DNSServer
$ZoneName = "x5.ru"

write-host "Enter Value with DNS name and IP (Enter and Enter to finish)"
while (1) 
  {
    read-host | set r
    set test -value ($test+"`n"+$r)
    if ($r.Length -lt 3) {break}
  }



$MessageToArray = $test.ToCharArray()
$MessageToArray = $test.split("`n")
$MessageToArray = $MessageToArray -replace '[^a-z0-9\.\-@_ =]'
$MessageToArray = $MessageToArray -replace '`n'



#Создаём DNS записи
foreach ($Line in $MessageToArray) {
    $DNS = $Line.Split(' ')[0]
    $DNSname = "$DNS" + ".mp"
    $IP = $Line.Split(' ')[1]
    if($DNSname.Length -gt 5) {
    Write-Host "Собираюсь создать $DNSname $IP"
    Add-DnsServerResourceRecordA -Name $DNSname -IPv4Address $IP -ZoneName $ZoneName -CreatePtr -ComputerName $DNSServer
    Write-Host "Создана запись A и PTR: $DNSname $IP"
    }    
}
