Remove-Variable * -ErrorAction SilentlyContinue

write-host "Enter Value with DNS name (Enter and Enter to finish)"
while (1) {
    read-host | set r
    set test -value ($test + "`n" + $r)
    if ($r.Length -lt 3) { break }
}


#Превращаем в удобоваримый вид, разделяя строки

$MessageToArray = $test.ToCharArray()
$MessageToArray = $test.split("`n")


#Собираем информацию о записи

$DNSServer = ""
$ZoneName = ""
$Logs = ""


ForEach ($NodeToDelete in $MessageToArray)
{
if ($NodeToDelete.Length -gt 3)
{
$NodeDNS = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -Node $NodeToDelete -RRType A -ErrorAction SilentlyContinue
if($NodeDNS -eq $null)
{
"
Не найдена DNS-запись $NodeToDelete. Не будет найдено A, PTR, IP, DHCP" >> $Logs
}
else
{
"
$NodeToDelete" >> $Logs
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
"Группа $GroupsNotFound не найдена" >> $Logs
} else {
        Remove-ADGroup -Identity $Group –Confirm:$false
        "Группа $Group удалена" >> $Logs
       }
$n = $n + 1
}

#Удаляем УЗ компьютера
try
{ 
Get-ADComputer -Identity $NodeToDelete | Remove-ADObject -Recursive -Confirm:$false
"Удалена УЗ компьютера $NodeToDelete" >> $Logs
}
catch
{"Не найдена УЗ компьютера $NodeToDelete" >> $Logs}



#Продолжаем скрипт только в случае найденной DNS-записи
if($NodeDNS -ne $null)
{
#Получаем IP нужной записи
$IPnodeDNS = $NodeDNS.RecordData.IPv4Address.IPAddressToString


#Присваиваем нужную обратную зону
$TempIPnodeDNS = $IPnodeDNS.Split(".")
if($TempIPnodeDNS[0] -eq '172') {if($TempIPnodeDNS[1] -eq '20') {if($TempIPnodeDNS[2] -eq '9'){$ReversScope = '9.20.172.in-addr.arpa'} else {$ReversScope = '20.172.in-addr.arpa'}}}


#Присваиваем обратное имя
$ReversName = $TempIPnodeDNS[3] + '.' + $TempIPnodeDNS[2]

#Удаляем А запись
Remove-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $ZoneName -RRType A -Name $NodeToDelete –Force
"Удалена A-запись $NodeToDelete" >> $Logs

#Удаляем обратную PTR-запись
Try
{
Remove-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $ReversScope -RRType PTR -Name $ReversName –Force
"Удалена обратная PTR-запись $ReversName" >> $Logs
}
catch
{"Обратной записи не найдено" >> $Logs}
}
}
}
