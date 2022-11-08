#Doesn't work if past of notepad win10

Remove-Variable * -ErrorAction SilentlyContinue
$dir = "V:\My"
$DNSServer = $Env:DNSServer
$DHCPServer = $Env:DHCPServer
$ZoneName = "x5.ru"

#Ввести данные в скрипт. Ввод данных заканчивается при получении короткой строки (Нажать Enter дважды)

write-host "Enter Value with DNS name (Enter and Enter to finish)"
while (1) {
    read-host | set r
    set test -value ($test + "`n" + $r)
    if ($r.Length -lt 3) { break }
}
cls

#Превращаем в удобоваримый вид, разделяя строки

$MessageToArray = $test.ToCharArray()
$MessageToArray = $test.split("`n")

#Создаём и очищаем временный файл, записываем в него инфо о системе и выводим результат

set-content -path "$dir\SystemType.csv" -value "Name; System; DHCP; DNS_IP"
$ErrorActionPreference = 'SilentlyContinue'

ForEach ($Name in $MessageToArray) {
    $Name = $Name -replace '[^a-z0-9\.\-@_=]'
    if ($Name.Length -gt 3) {
        Write-Host "Собираю информацию о $Name"
        $Info = get-adcomputer -Identity $Name -Properties OperatingSystem
        $DNS = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DNSServer -Node $Name -RRType A -ErrorAction SilentlyContinue
        $DNS_IP = $DNS.RecordData.IPv4Address.IPAddressToString
        $DHCP_Lease = Get-DhcpServerv4Lease -ComputerName $DHCPServer -IPAddress $DNS_IP
        
        if ($DHCP_Lease -eq $null) { $DHCP = "No" } else { $DHCP = "Yes" }
        if ($Info.OperatingSystem -eq $null) { $Info.OperatingSystem = "Linux" }        
        
        $Text = $Name + ";" + $Info.OperatingSystem + ";" + "$DHCP" + ";" + $DNS_IP
        add-content -path "$dir\SystemType.csv" -value $Text
    }            
}

$info2 = Import-Csv -Delimiter ";" -Path "$dir\SystemType.csv"
$info2 | Format-Table -AutoSize

#В случае, если есть машины на ручных сетевых настройках создаётся файл для mRemote с этими машинами

$NoDHCPNodes = $info2 | Where-Object -Property DHCP -like No
if ($NoDHCPNodes -ne $null) {
    set-content -path "$dir\DHCP.xml" -value '<?xml version="1.0" encoding="utf-8"?>'
    Add-Content -path "$dir\DHCP.xml" -value '<mrng:Connections xmlns:mrng="http://mremoteng.org" Name="Подключения" Export="false" EncryptionEngine="AES" BlockCipherMode="GCM" KdfIterations="1000" FullFileEncryption="false" Protected="36wSJzFLI27Datn1Jrtk+4mAqm1jnDb8xj3nDSEck0i/8uqWMfkhIEB3DgxP9BcJsyL15JUVDVL39aVhpuatcglA" ConfVersion="2.6">'
    foreach ($Name in $NoDHCPNodes.Name) {
        $NodeLine = '    <Node Name=' + '"' + $Name + '" ' + 'Type="Connection" Icon="mRemoteNG" Panel="General" Username="" Domain="" Password="" Hostname=' + '"' + $Name + '"' + ' Protocol="RDP" PuttySession="Default Settings" Port="3389" ConnectToConsole="false" UseCredSsp="true" RenderingEngine="IE" ICAEncryptionStrength="EncrBasic" RDPAuthenticationLevel="NoAuth" RDPMinutesToIdleTimeout="0" RDPAlertIdleTimeout="false" LoadBalanceInfo="" Colors="Colors16Bit" Resolution="SmartSize" AutomaticResize="true" DisplayWallpaper="false" DisplayThemes="false" EnableFontSmoothing="false" EnableDesktopComposition="false" CacheBitmaps="false" RedirectDiskDrives="false" RedirectPorts="false" RedirectPrinters="false" RedirectSmartCards="false" RedirectSound="DoNotPlay" SoundQuality="Dynamic" RedirectKeys="false" Connected="false" PreExtApp="" PostExtApp="" MacAddress="" UserField="" ExtApp="" VNCCompression="CompNone" VNCEncoding="EncHextile" VNCAuthMode="AuthVNC" VNCProxyType="ProxyNone" VNCProxyIP="" VNCProxyPort="0" VNCProxyUsername="" VNCProxyPassword="" VNCColors="ColNormal" VNCSmartSizeMode="SmartSAspect" VNCViewOnly="false" RDGatewayUsageMethod="Never" RDGatewayHostname="" RDGatewayUseConnectionCredentials="Yes" RDGatewayUsername="" RDGatewayPassword="" RDGatewayDomain="" InheritCacheBitmaps="false" InheritColors="false" InheritDescription="false" InheritDisplayThemes="false" InheritDisplayWallpaper="false" InheritEnableFontSmoothing="false" InheritEnableDesktopComposition="false" InheritDomain="false" InheritIcon="false" InheritPanel="false" InheritPassword="false" InheritPort="false" InheritProtocol="false" InheritPuttySession="false" InheritRedirectDiskDrives="false" InheritRedirectKeys="false" InheritRedirectPorts="false" InheritRedirectPrinters="false" InheritRedirectSmartCards="false" InheritRedirectSound="false" InheritSoundQuality="false" InheritResolution="false" InheritAutomaticResize="false" InheritUseConsoleSession="false" InheritUseCredSsp="false" InheritRenderingEngine="false" InheritUsername="false" InheritICAEncryptionStrength="false" InheritRDPAuthenticationLevel="false" InheritRDPMinutesToIdleTimeout="false" InheritRDPAlertIdleTimeout="false" InheritLoadBalanceInfo="false" InheritPreExtApp="false" InheritPostExtApp="false" InheritMacAddress="false" InheritUserField="false" InheritExtApp="false" InheritVNCCompression="false" InheritVNCEncoding="false" InheritVNCAuthMode="false" InheritVNCProxyType="false" InheritVNCProxyIP="false" InheritVNCProxyPort="false" InheritVNCProxyUsername="false" InheritVNCProxyPassword="false" InheritVNCColors="false" InheritVNCSmartSizeMode="false" InheritVNCViewOnly="false" InheritRDGatewayUsageMethod="false" InheritRDGatewayHostname="false" InheritRDGatewayUseConnectionCredentials="false" InheritRDGatewayUsername="false" InheritRDGatewayPassword="false" InheritRDGatewayDomain="false" />'
        Add-Content -path "$dir\DHCP.xml" -value $NodeLine
    }
    Add-Content -path "$dir\DHCP.xml" -value '</mrng:Connections>'
    Set-Clipboard "V:\I.Vityukhovsky-3-9\My"
    $Message = "
Path copy in clipboard"
    $Message
}
