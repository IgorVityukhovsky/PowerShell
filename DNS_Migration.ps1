Remove-Variable * -ErrorAction SilentlyContinue

$ZoneName = "x5.ru"
$DNSServer = $Env:DNSServer


$MessageToArray = $null
$test = $null
$OneLine = $null


write-host "Enter Value with DNS name and IP (Enter and Enter to finish)"
while (1) 
  {
    read-host | set r
    set test -value ($test+"`n"+$r)
    if ($r.Length -lt 3) {break}
  }
cls


$MessageToArray = $test.ToCharArray()
$MessageToArray = $test.split("`n")


Foreach ($Line in $MessageToArray){
    $OneLine = $OneLine + " " + $Line
}


$OneLine = $OneLine.TrimStart(" ")
$OneLine = $OneLine.replace("DNS Name:", "")
$OneLine = $OneLine.replace(".x5.ru", "")
$OneLine = $OneLine.replace(".x5", "")
$OneLine = $OneLine.replace("IP Address:", "")
$OneLine = $OneLine.Split(" ")
$Name = $OneLine[0]
$NewIP = $OneLine[1]
$Name = $Name -replace '[^a-z0-9\.\-@_=]'



$NewADNS = get-DnsServerResourceRecord -Name $Name -ZoneName $ZoneName -ComputerName $DNSServer
$OldADNS = get-DnsServerResourceRecord -Name $Name -ZoneName $ZoneName -ComputerName $DNSServer

$NewADNS.RecordData.IPv4Address = [System.Net.IPAddress]::parse("$NewIP")

Set-DnsServerResourceRecord -NewInputObject $NewADNS -OldInputObject $OldADNS -ZoneName $ZoneName -ComputerName $DNSServer
Remove-DnsServerResourceRecord -ZoneName $ZoneName -RRType A -Name $Name -Force -ComputerName $DNSServer

Add-DnsServerResourceRecordA -Name $Name -IPv4Address $NewIP -ZoneName $ZoneName -CreatePtr -ComputerName $DNSServer

$Message = "$Name обновил DNS"
Set-Clipboard $Message
Write-Host -Object "$Message" -BackgroundColor Black -ForegroundColor Green
