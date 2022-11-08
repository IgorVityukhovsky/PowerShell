#Для работы скрипта необходимо импортировать модуль: Install-Module ImportExcel -Scope CurrentUser

Remove-Variable * -ErrorAction SilentlyContinue

$DNSServer = "msk-kltn-ads009"
$ZoneName = "x5.ru"
$dir = "V:\Downloads"

#Импортируем инфо. Берёт самый свежий файл из директории
$latest = Get-ChildItem -Path $dir | Sort-Object LastAccessTime -Descending | Select-Object -First 1
$Path = $dir + "\" + $latest.name
$Info = Import-Excel -Path $Path

#Выдираем нужные данные во временный файл
#newhost в приоритете над hostname - добавить позже. Если newhost -ne 0, то записать в hostname
#IP берётся из столбцов: IP-MGMT, IP

set-content -path "$dir\2.csv" -value "Host; IP"
foreach ($Line in $Info) {    
    if ($Line.IP -ne $null) {
        $IP = ($Line.IP).replace("`n", ",")
    }
    else {    
        if ($Line.'IP-MGMT' -ne $null) {
            $IP = ($Line.'IP-MGMT').replace("`n", ",")
        }
        else {
            if ($Line.'IP-Address' -ne $null) {
                $IP = ($Line.'IP-Address').replace("`n", ",")
        }
    }
    if ($Line.hostname -ne $null) {
        $Hostname = ($Line.hostname)
        $Text = $Hostname + ";" + $IP    
        add-content -path "$dir\2.csv" -value $Text
    }    
}
}


#Создаём итоговый файл для DNS
$info2 = Import-Csv -Delimiter ";" -Path "$dir\2.csv"
set-content -path "$dir\3.txt" -value $null
foreach ($Line in $info2) {
    foreach ($newIP in ($Line.IP).Split(',')) {
        $ZPT = ","
        $Text = $Line.Host + $ZPT + $newIP
        $Text >> $dir\3.txt
    }
}

#Ищем старые A-записи, если находим - логируем и удаляем
$NodeDNS = $null
$TempDNSremove = Get-Content $dir\3.txt
foreach ($NodeDNS in $TempDNSremove) {
    $DNS = $NodeDNS.Split(',')[0]
    $NodeDNS = $DNS + ".mp"
    $NodeDNS = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -Node $NodeDNS -RRType A -ErrorAction SilentlyContinue
    if ($NodeDNS -eq $null) {
        Write-Host "Не найдена DNS-запись $DNS"
    } 
    else {
        $NodeTOdelete = ($NodeDNS.HostName).Split(',')[0]
        $OldRecord = $NodeTOdelete + ' ' + $NodeDNS.RecordData.IPv4Address.IPAddressToString
        $OldRecord >> $dir\oldrecord.txt
        Remove-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $ZoneName -RRType A -Name $NodeTOdelete –Force
        Write-Host "Удалена A-запись $DNS"
    }
}

#Ищем старые PTR-записи и удаляем

#Получаем IP нужной записи из временного файла

foreach ($NodeDNS in $TempDNSremove) {
    $IPnodeDNS = $NodeDNS.Split(',')[1]

    #Присваиваем нужную обратную зону

    $TempIPnodeDNS = $IPnodeDNS.Split(".")
    if ($TempIPnodeDNS[0] -eq '10') { $ReversScope = '10.in-addr.arpa' }
    if ($TempIPnodeDNS[0] -eq '100') { $ReversScope = '100.in-addr.arpa' }
    if ($TempIPnodeDNS[0] -eq '192') { if ($TempIPnodeDNS[1] -eq '168') { $ReversScope = '168.192.in-addr.arpa' } else { "Нет такой зоны $IPnodeDNS" } }
    if ($TempIPnodeDNS[0] -eq '172') { if ($TempIPnodeDNS[1] -eq '16') { $ReversScope = '16.172.in-addr.arpa' } if ($TempIPnodeDNS[1] -eq '20') { $ReversScope = '20.172.in-addr.arpa' } if ($TempIPnodeDNS[1] -eq '31') { $ReversScope = '31.172.in-addr.arpa' } else { "Нет такой зоны $IPnodeDNS" } }


    #Присваиваем обратное имя
    $ReversName = $TempIPnodeDNS[3] + '.' + $TempIPnodeDNS[2]

    #Удаляем обратную PTR-запись
    Try {
        Remove-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $ReversScope -RRType PTR -Name $ReversName –Force
        Write-Host "Удалена обратная PTR-запись $ReversName"
    }
    catch
    { Write-Host "Обратной записи не найдено" }
}


#Создаём DNS записи
$info3 = Get-Content $dir\3.txt
foreach ($Line in $info3) {
    $DNS = $Line.Split(',')[0]
    $DNSname = "$DNS" + ".mp"
    $IP = $Line.Split(',')[1]
    Add-DnsServerResourceRecordA -Name $DNSname -IPv4Address $IP -ZoneName $ZoneName -CreatePtr -ComputerName $DNSServer
    Write-Host "Создана запись A и PTR: $DNSname $IP"    
}
