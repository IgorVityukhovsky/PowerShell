#EXAMPLE 
#.\ipcalc.ps1 10.10.100.5/24 Name


param ( 
    [Parameter(Mandatory=$True,Position=1)] 
    [string]$IPAddress, 
    [Parameter(Mandatory=$True,Position=2)] 
    [string]$Name,
    [Parameter(Mandatory=$False,Position=3)] 
    [string]$Netmask 
    ) 

function toBinary ($dottedDecimal){ 
 $dottedDecimal.split(".") | %{$binary=$binary + $([convert]::toString($_,2).padleft(8,"0"))} 
 return $binary 
} 
function toDottedDecimal ($binary){ 
 do {$dottedDecimal += "." + [string]$([convert]::toInt32($binary.substring($i,8),2)); $i+=8 } while ($i -le 24) 
 return $dottedDecimal.substring(1) 
} 

function CidrToBin ($cidr){ 
    if($cidr -le 32){ 
        [Int[]]$array = (1..32) 
        for($i=0;$i -lt $array.length;$i++){ 
            if($array[$i] -gt $cidr){$array[$i]="0"}else{$array[$i]="1"} 
        } 
        $cidr =$array -join "" 
    } 
    return $cidr 
} 

function NetMasktoWildcard ($wildcard) { 
    foreach ($bit in [char[]]$wildcard) { 
        if ($bit -eq "1") { 
            $wildcardmask += "0" 
            } 
        elseif ($bit -eq "0") { 
            $wildcardmask += "1" 
            } 
        } 
    return $wildcardmask 
    } 


# Check to see if the IP Address was entered in CIDR format 
if ($IPAddress -like "*/*") { 
    $CIDRIPAddress = $IPAddress 
    $IPAddress = $CIDRIPAddress.Split("/")[0] 
    $cidr = [convert]::ToInt32($CIDRIPAddress.Split("/")[1]) 
    if ($cidr -le 32 -and $cidr -ne 0) { 
        $ipBinary = toBinary $IPAddress 
        $smBinary = CidrToBin($cidr) 
        $Netmask = toDottedDecimal($smBinary) 
        $wildcardbinary = NetMasktoWildcard ($smBinary) 
        } 
    else { 
        Write-Warning "Subnet Mask is invalid!" 
        Exit 
        } 
    } 
else { 
    if (!$Netmask) { 
        $Netmask = Read-Host "Netmask" 
        } 
    $ipBinary = toBinary $IPAddress 
    if ($Netmask -eq "0.0.0.0") { 
        Write-Warning "Subnet Mask is invalid!" 
        Exit 
        } 
    else { 
        $smBinary = toBinary $Netmask 
        $wildcardbinary = NetMasktoWildcard ($smBinary) 
        } 
    } 

#how many bits are the network ID 
$netBits=$smBinary.indexOf("0") 
if ($netBits -ne -1) { 
    $cidr = $netBits 
    #validate the subnet mask 
    if(($smBinary.length -ne 32) -or ($smBinary.substring($netBits).contains("1") -eq $true)) { 
        Write-Warning "Subnet Mask is invalid!" 
        Exit 
        } 
    #validate that the IP address 
    if(($ipBinary.length -ne 32) -or ($ipBinary.substring($netBits) -eq "00000000") -or ($ipBinary.substring($netBits) -eq "11111111")) { 
        Write-Warning "IP Address is invalid!" 
        Exit 
        } 
    #identify subnet boundaries 
    $networkID = toDottedDecimal $($ipBinary.substring(0,$netBits).padright(32,"0")) 
    $firstAddress = toDottedDecimal $($ipBinary.substring(0,$netBits).padright(31,"0") + "1") 
    $lastAddress = toDottedDecimal $($ipBinary.substring(0,$netBits).padright(31,"1") + "0") 
    $broadCast = toDottedDecimal $($ipBinary.substring(0,$netBits).padright(32,"1")) 
    $wildcard = toDottedDecimal ($wildcardbinary) 
    $networkIDbinary = $ipBinary.substring(0,$netBits).padright(32,"0") 
    $broadCastbinary = $ipBinary.substring(0,$netBits).padright(32,"1") 
    $Hostspernet = ([convert]::ToInt32($broadCastbinary,2) - [convert]::ToInt32($networkIDbinary,2)) - 1 
   } 
else { 
    #identify subnet boundaries 
    $networkID = toDottedDecimal $($ipBinary) 
    $firstAddress = toDottedDecimal $($ipBinary) 
    $lastAddress = toDottedDecimal $($ipBinary) 
    $broadCast = toDottedDecimal $($ipBinary) 
    $wildcard = toDottedDecimal ($wildcardbinary) 
    $Hostspernet = 1 
    } 


#Results 
#Write-Host "`nAddress:`t`t$IPAddress" 
#Write-Host "Netmask:`t`t$Netmask = $cidr" 
#Write-Host "Wildcard:`t`t$wildcard" 
#Write-Host "=>" 
#Write-Host "Network:`t`t$networkID/$cidr" 
#Write-Host "Broadcast:`t`t$broadCast" 
#Write-Host "HostMin:`t`t$firstAddress" 
#Write-Host "HostMax:`t`t$lastAddress" 
#Write-Host "Hosts/Net:`t`t$Hostspernet`n"  

$DefGet = $firstAddress
$lastOctet = [int]$firstAddress.Split('.')[3]
$lastOctetHostMin = $lastOctet+1
$lastOctetScopeID = $lastOctet-1
$HostMin = $firstAddress.Split('.')[0] + '.' + $firstAddress.Split('.')[1] + '.' + $firstAddress.Split('.')[2] + '.' + $lastOctetHostMin
$HostMax = $lastAddress
$ScopeID = $firstAddress.Split('.')[0] + '.' + $firstAddress.Split('.')[1] + '.' + $firstAddress.Split('.')[2] + '.' + $lastOctetScopeID

Write-Host "Next Scope will be created"
Write-Host "Name: $Name"
Write-Host "Router: $DefGet"
Write-Host "HostMin: $HostMin"
Write-Host "HostMax: $HostMax"
Write-Host "ScopeID: $ScopeID"
Write-Host "SubnetMask: $Netmask"

$DHCPServer = $Env:DHCPServer

Add-DhcpServerv4Scope -Name $Name -StartRange $HostMin -EndRange $HostMax -SubnetMask $Netmask -ComputerName $DHCPServer
Set-DhcpServerv4OptionValue -ScopeId $ScopeID -Router $DefGet -ComputerName $DHCPServer
