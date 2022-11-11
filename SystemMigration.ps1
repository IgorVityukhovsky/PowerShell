
Remove-Variable * -ErrorAction SilentlyContinue
Connect-VIServer $Env:VIServer | Out-Null


$dir = "V:\My"
$DNSServer = $Env:DNSServer
$DHCPServer = $Env:DHCPServer
$ZoneName = "x5.ru"

$Nodes = Get-Content "$dir\SystemMigration.txt"
$n = 0

$Nodes = $Nodes -replace '[^a-z0-9\.\-@_ =]'
$Nodes = $Nodes.replace(" 823", " VLAN823_win_L_D") 
$Nodes = $Nodes.replace(" 190", " VLAN190_win")
$Nodes = $Nodes.replace(" 820", " VLAN820_app_L_D")
$Nodes = $Nodes.replace(" 821", " VLAN821_ora_L_D")
$Nodes = $Nodes.replace(" 831", " VLAN831_L_D")
$Nodes = $Nodes.replace(" 475", " VLAN475_win")
$Nodes = $Nodes.replace(" 187", " VLAN187_temp_L")
$Nodes = $Nodes.replace(" 925", " VLAN925_loymax_L")
$Nodes = $Nodes.replace(" 822", " VLAN822_rhel_L_D")
$Nodes = $Nodes.replace(" 824", " VLAN824_fnr_L_D")

$ErrorActionPreference = "SilentlyContinue"

#Генерируем файл куда будем складывать инфу

set-content -path "$dir\SystemMigration.csv" -value "Number; System; Name; VM_IP; DNS_IP; DHCP; Target_VLAN; Fact_VLAN"
ForEach ($Line in $Nodes) {
    $Line = $Line.Split(" ")
    $Name = $Line[0]
    $Target_VLAN = $Line[1]
    
    Write-Host "Собираю информацию о $Name"

    $DNS = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -Node $Name -RRType A -ErrorAction SilentlyContinue
    $DNS_IP = $DNS.RecordData.IPv4Address.IPAddressToString
    $DHCP_Lease = Get-DhcpServerv4Lease -ComputerName $DHCPServer -IPAddress $DNS_IP
    if ($DHCP_Lease -eq $null) { $DHCP = "No" } else { $DHCP = "Yes" }
    $VMinfo = Get-VM $Name
    $VM_IP = $VMinfo.Guest.IPAddress | Where-Object -FilterScript { $PSItem.Length -le 16 }
    
    #если IP машины и DNS не соответствуют, закомментировать строку
    
    if ($VM_IP.Count -gt 1) { $VM_IP = $VM_IP[0] }
    
    $Network = $VMinfo | Get-NetworkAdapter
    $Fact_VLAN = $Network.NetworkName

    $System = $VMinfo.Guest.OSFullName
    $System = $System.TrimEnd('(64-bit)')
    $System = $System.TrimEnd('(32-bit)')
    $n = $n + 1
    $number = "$n"


    $Text = $number + ";" + $System + ";" + $Name + ";" + $VM_IP + ";" + $DNS_IP + ";" + $DHCP + ";" + $Target_VLAN + ";" + $Fact_VLAN
    add-content -path "$dir\SystemMigration.csv" -value $Text
}

$info = Import-Csv -Delimiter ";" -Path "$dir\SystemMigration.csv"
$info | Format-Table -AutoSize

#Выбор действий

Write-Host "1 - Change VLAN: ALL"
Write-Host "2 - Change VLAN: Windows"
Write-Host "3 - Change DNS: ALL"
Write-Host "4 - Change DNS: Linux"
Write-Host "5 - Create DHCP reservation"
Write-Host "0 - Exit"

$Choise = Read-Host
If ($Choise -eq 1) {
    foreach ($LineInfo in $info) {
        get-vm $LineInfo.Name | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $LineInfo.Target_VLAN -Confirm:$false
    }
}
else {
    If ($Choise -eq 2) {
        foreach ($LineInfo in $info) {
            If ($LineInfo.System.Contains("Windows")  ){
                get-vm $LineInfo.Name | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $LineInfo.Target_VLAN -Confirm:$false
            }
        }
    }
    else{
        if ($Choise -eq 3){
            foreach ($LineInfo in $info){
                if ($LineInfo.VM_IP.Count -gt 1) { $LineInfo.VM_IP = $VM_IP[0] }
                if ($LineInfo.VM_IP -ne $LineInfo.DNS_IP){

                    $NewADNS = get-DnsServerResourceRecord -Name $LineInfo.name -ZoneName $ZoneName -ComputerName $DNSServer
                    $OldADNS = get-DnsServerResourceRecord -Name $LineInfo.name -ZoneName $ZoneName -ComputerName $DNSServer
                    $NewADNS.RecordData.IPv4Address = [System.Net.IPAddress]::parse("$LineInfo.VM_IP")
                    Set-DnsServerResourceRecord -NewInputObject $NewADNS -OldInputObject $OldADNS -ZoneName $ZoneName -ComputerName $DNSServer
                    Remove-DnsServerResourceRecord -ZoneName $ZoneName -RRType A -Name $LineInfo.name -Force -ComputerName $DNSServer
                    Add-DnsServerResourceRecordA -Name $LineInfo.name -IPv4Address $LineInfo.VM_IP -ZoneName $ZoneName -CreatePtr -ComputerName $DNSServer
                }

            }
        }
        else {
            if ($Choise -eq 4){
                foreach ($LineInfo in $info){
                    if ($LineInfo.VM_IP.Count -gt 1) { $LineInfo.VM_IP = $VM_IP[0] }
                    If ($LineInfo.System -notcontains "Windows"  ){
                        $NewADNS = get-DnsServerResourceRecord -Name $LineInfo.name -ZoneName $ZoneName -ComputerName $DNSServer
                        $OldADNS = get-DnsServerResourceRecord -Name $LineInfo.name -ZoneName $ZoneName -ComputerName $DNSServer
                        $NewADNS.RecordData.IPv4Address = [System.Net.IPAddress]::parse("$LineInfo.VM_IP")
                        Set-DnsServerResourceRecord -NewInputObject $NewADNS -OldInputObject $OldADNS -ZoneName $ZoneName -ComputerName $DNSServer
                        Remove-DnsServerResourceRecord -ZoneName $ZoneName -RRType A -Name $LineInfo.name -Force -ComputerName $DNSServer
                        Add-DnsServerResourceRecordA -Name $LineInfo.name -IPv4Address $LineInfo.VM_IP -ZoneName $ZoneName -CreatePtr -ComputerName $DNSServer
                    }
                }
            }
            else {
                if ($Choise -eq 0){break}
                else {
                    if ($Choise -eq 5){
                        Write-Host "Enter Number for create DHCP reservation (for example: 1 4 5):
                        "
                        $Choise5 = Read-Host
                        $Choise5 = $Choise5.split(" ")
                        foreach ($EnterNumber in $Choise5){
                            foreach ($LineInfo in $info) {
                                if ($EnterNumber -eq $LineInfo.Number){
                                    Get-DhcpServerv4Lease -ComputerName $DHCPServer -IPAddress $LineInfo.DNS_IP | Add-DhcpServerv4Reservation -ComputerName $DHCPServer
                                    $ReservationAccess = $ReservationAccess + "," + $LineInfo.Name
                                }
                            }
                        }
                        $Message = "VLAN сменены, DNS обновлены, созданы резервации для $ReservationAccess"
                        Set-Clipboard $Message
                        Write-Host -Object "$Message" -BackgroundColor Black -ForegroundColor Green
                    }
                }
            }
        
        }
    }
}
