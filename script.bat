function Validate-IPAddress {
    param([string]$IPAddress)

    $ipRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
    $validIP = $IPAddress -match $ipRegex

    return $validIP
}

function Validate-SubnetMask {
    param([string]$SubnetMask)

    $maskRegex = "^([0-9]|[1-2][0-9]|3[0-2])$"
    $validMask = $SubnetMask -match $maskRegex

    return $validMask
}


$validAdapter = $false

do {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }  # Obtient la liste des adaptateurs réseau actifs
    Write-Host "Adaptateurs réseau disponibles :"
    $index = 1
    foreach ($adapter in $adapters) {
        Write-Host "$index. $($adapter.Name)"
        $index++
    }

    $choice = Read-Host -Prompt "Sélectionnez le numéro de l'adaptateur réseau à configurer"
    $choice = [int]$choice
    $numberOfAdapters = 1
    if($adapters -is [system.array]){
       $numberOfAdapters = $adapters.Count
    }

    if ($choice -ge 1 -and $choice -le $numberOfAdapters) {
        $selectedAdapter = $adapters[$choice - 1]
        $validAdapter = $true
    } else {
        Write-Host "Choix d'adaptateur non valide. Veuillez réessayer."
    }
} until ($validAdapter)

$validIP = $false

do {
    $ipAddress = Read-Host -Prompt "Entrez l'adresse IP statique :"
    $validIP = Validate-IPAddress -IPAddress $ipAddress

    if (-not $validIP) {
        Write-Host "Adresse IP non valide. Veuillez réessayer."
    }
} until ($validIP)

$validSubnetMask = $false

do {
    $subnetMask = Read-Host -Prompt "Entrez le masque de sous-réseau :"
    $validSubnetMask = Validate-SubnetMask -SubnetMask $subnetMask

    if (-not $validSubnetMask) {
        Write-Host "Masque de sous-réseau non valide. Veuillez réessayer."
    }
} until ($validSubnetMask)

$defaultGateway = Read-Host -Prompt "Entrez la passerelle par défaut :"

$dnsServers = (Read-Host -Prompt "Entrez les adresses IP des serveurs DNS (séparées par des virgules en cas de plusieurs adresses) :").Split(',')

$adapterConfig = $selectedAdapter | Get-NetIPConfiguration
# $adapterConfig | Set-NetIPAddress -InterfaceMetric 10  # Définit une métrique d'interface pour éviter les conflits avec d'autres connexions

$IPType = "IPv4"
#  disable dhcp only if user choose static mode
$interface = $adapterConfig | Get-NetIPInterface -AddressFamily $IPType
$interface | Set-NetIPInterface -DHCP Enabled

$adapterConfig | New-NetIPAddress `
 -AddressFamily $IPType `
 -IPAddress $ipAddress `
 -PrefixLength $subnetMask `
 -DefaultGateway $defaultGateway
$adapterConfig | Set-DnsClientServerAddress -ServerAddresses $dnsServers

# $adapterConfig | Set-NetIPAddress -DHCP Disabled
# $adapterConfig | Set-NetIPAddress -IPAddress $ipAddress -PrefixLength $subnetMask
# $adapterConfig | Set-NetIPAddress -DefaultGateway $defaultGateway
# $adapterConfig | Set-DnsClientServerAddress -ServerAddresses $dnsServers

Write-Host "L'adresse IP a été configurée avec succès pour $($selectedAdapter.Name)."

# Vérification de la connectivité
$pingResult = Test-Connection -ComputerName "www.google.com" -Count 1 -Quiet

if ($pingResult) {
    Write-Host "La connectivité Internet est établie."
} else {
    Write-Host "Impossible de se connecter à Internet."
}
