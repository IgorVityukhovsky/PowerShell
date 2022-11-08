Remove-Variable * -ErrorAction SilentlyContinue

$DHCPServer = $Env:DHCPServer
$Info = Import-Excel -Path V:\My\CreateDHCPReservation.xlsx
foreach($Line in $Info){
$Line.ClientId = $Line.ClientId.replace(":", "")
Add-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $Line.ScopeId -IPAddress $Line.IPAddress -Name $Line.Name -ClientId $Line.ClientId -Description $Line.Description
$Text = "Создана резервация " + $Line.Name
Write-Host $Text
}
