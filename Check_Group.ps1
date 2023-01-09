Remove-Variable * -ErrorAction SilentlyContinue

$Nodes = Get-Content 'C:\My\CompList.txt'

$prfx = "g-x5-"
$sffx1 = "-sudo"
$sffx2 = "-access"
$attrs = @{extensionAttribute4="3"}

$ExistGroup
$NotExistGroup

$Nodes | ForEach {
    $GroupSudo = $prfx+$_+$sffx1 
    $GroupAccess = $prfx+$_+$sffx2

    Try {
        Get-ADGroup $GroupSudo | Out-Null
        $ExistGroup = $ExistGroup + "`n" + $GroupSudo
    } catch {
        $NotExistGroup = $NotExistGroup  + "`n" + $GroupSudo
        New-ADGroup -name $GroupSudo -GroupScope Global -GroupCategory Security -Path "" -OtherAttributes $attrs
        
    }

    Try {
        Get-ADGroup $GroupAccess | Out-Null
        $ExistGroup = $ExistGroup + "`n" + $GroupAccess
    } catch {
        $NotExistGroup = $NotExistGroup  + "`n" + $GroupAccess
        New-ADGroup -name $GroupAccess -GroupScope Global -GroupCategory Security -Path ""     
    }
}

Write-Host  $ExistGroup -ForeGroundColor Green
Write-Host  "Will be created:
$NotExistGroup"
