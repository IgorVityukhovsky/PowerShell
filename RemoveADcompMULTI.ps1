Remove-Variable * -ErrorAction SilentlyContinue

$NodesToDelete = Get-Content 'V:\My\Компы\RemoveCompList.txt'

#Собираем информацию о записи

$DNSServer = $Env:DNSServer
$DHCPServer = $Env:DHCPServer
$ZoneName = "x5.ru"

$Reservations = Get-DhcpServerv4Scope -Computer $DHCPServer | Get-DhcpServerv4Reservation -Computer $DHCPServer

ForEach ($NodeToDelete in $NodesToDelete)
{
$NodeDNS = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -Node $NodeToDelete -RRType A -ErrorAction SilentlyContinue
if($NodeDNS -eq $null)
{
"
Не найдена DNS-запись $NodeToDelete. Не будет найдено A, PTR, IP, DHCP" >> V:\My\Компы\RemoveCompLOGS.txt
}
else
{
"
$NodeToDelete" >> V:\My\Компы\RemoveCompLOGS.txt
}

#Ищем группы и удаляем
#Шаблоны групп
$WinGroupAdmins = 'L' + '-' + $NodeToDelete + '-' + 'Admins'
$WinGroupUsers = 'L' + '-' + $NodeToDelete + '-' + 'Users'
$WinGroupRDPUsers = 'L' + '-' + $NodeToDelete + '-' + 'RDP' + '-' + 'Users'
$LinuxGroupSudo = 'G' + '-' + 'X5' + '-' + $NodeToDelete + '-' + 'Sudo'
$LinuxGroupAccess = 'G' + '-' + 'X5' + '-' + $NodeToDelete + '-' + 'Access'

#Поиск групп
$SearchWinGroupAdmins = Get-ADGroup -Filter {SamAccountName -eq $WinGroupAdmins}
$SearchWinGroupUsers = Get-ADGroup -Filter {SamAccountName -eq $WinGroupUsers}
$SearchWinGroupRDPUsers = Get-ADGroup -Filter {SamAccountName -eq $WinGroupRDPUsers}
$SearchLinuxGroupSudo = Get-ADGroup -Filter {SamAccountName -eq $LinuxGroupSudo}
$SearchLinuxGroupAccess = Get-ADGroup -Filter {SamAccountName -eq $LinuxGroupAccess}
$Groups = @($SearchWinGroupAdmins, $SearchWinGroupUsers, $SearchWinGroupRDPUsers, $SearchLinuxGroupSudo, $SearchLinuxGroupAccess)
$GroupsForMessage = @($WinGroupAdmins, $WinGroupUsers, $WinGroupRDPUsers, $LinuxGroupSudo, $LinuxGroupAccess)

$n = 0
ForEach ($Group in $Groups)
{
if($Group -eq $null)
{
$GroupsNotFound = $GroupsForMessage[$n]
"Группа $GroupsNotFound не найдена" >> V:\My\Компы\RemoveCompLOGS.txt
} else {
        Remove-ADGroup -Identity $Group –Confirm:$false
        "Группа $Group удалена" >> V:\My\Компы\RemoveCompLOGS.txt
       }
$n = $n + 1
}

#Удаляем УЗ компьютера
try
{
Get-ADComputer -Identity $NodeToDelete | Remove-ADObject -Recursive -Confirm:$false
"Удалена УЗ компьютера $NodeToDelete" >> V:\My\Компы\RemoveCompLOGS.txt
}
catch
{"Не найдена УЗ компьютера $NodeToDelete" >> V:\My\Компы\RemoveCompLOGS.txt}

#Удаляем резервации по имени машины

$Reservation = $Reservations | Where-Object { $_.Name -eq $NodeToDelete+".x5.ru" }


if ($Reservation) {
    $Reservation | Remove-DhcpServerv4Reservation -Computer $DHCPServer
    "Удалена DHCP резервация $NodeToDelete" >> V:\My\Компы\RemoveCompLOGS.txt

  } else {
    "Не найдена DHCP резервация $NodeToDelete" >> V:\My\Компы\RemoveCompLOGS.txt
}

#Продолжаем скрипт только в случае найденной DNS-записи
if($NodeDNS -ne $null)
{
#Получаем IP нужной записи
$IPnodeDNS = $NodeDNS.RecordData.IPv4Address.IPAddressToString


#Присваиваем нужную обратную зону
$TempIPnodeDNS = $IPnodeDNS.Split(".")
if($TempIPnodeDNS[0] -eq '10') {$ReversScope = '10.in-addr.arpa'}
if($TempIPnodeDNS[0] -eq '100') {$ReversScope = '100.in-addr.arpa'}
if($TempIPnodeDNS[0] -eq '192') {if($TempIPnodeDNS[1] -eq '168'){$ReversScope = '168.192.in-addr.arpa'} else {"Нет такой зоны $IPnodeDNS"}}
if($TempIPnodeDNS[0] -eq '172') {if($TempIPnodeDNS[1] -eq '16'){$ReversScope = '16.172.in-addr.arpa'} if($TempIPnodeDNS[1] -eq '20'){$ReversScope = '20.172.in-addr.arpa'} if($TempIPnodeDNS[1] -eq '31'){$ReversScope = '31.172.in-addr.arpa'} else {"Нет такой зоны $IPnodeDNS"}}


#Присваиваем обратное имя
$ReversName = $TempIPnodeDNS[3] + '.' + $TempIPnodeDNS[2]

#Удаляем А запись
Remove-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $ZoneName -RRType A -Name $NodeToDelete –Force
"Удалена A-запись $NodeToDelete" >> V:\My\Компы\RemoveCompLOGS.txt

#Удаляем обратную PTR-запись
Try
{
Remove-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $ReversScope -RRType PTR -Name $ReversName –Force
"Удалена обратная PTR-запись $ReversName" >> V:\My\Компы\RemoveCompLOGS.txt
}
catch
{"Обратной записи не найдено" >> V:\My\Компы\RemoveCompLOGS.txt}

#Удаляем DHCP-запись
$ErrorActionPreference = 'SilentlyContinue'
$DHCP = get-DhcpServerv4Lease -ComputerName $DHCPServer -IPAddress $IPnodeDNS
 
if($DHCP -ne $null)
{
Remove-DhcpServerv4Lease -ComputerName $DHCPServer -IPAddress $IPnodeDNS
"Удалена DHCP-запись $IPnodeDNS" >> V:\My\Компы\RemoveCompLOGS.txt
}
else
{
"Не найдена DHCP-запись $IPnodeDNS" >> V:\My\Компы\RemoveCompLOGS.txt
}
}
}
