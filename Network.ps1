function Get-VBoxVMNetworkAdapter {
    <#
    .SYNOPSIS
        Zeigt die Netzwerkadapter einer VM.
    .DESCRIPTION
        Das Cmdlet Get-VBoxVMNetworkAdapter gibt die aktiven Netzwerkadapter einer VM zurück, mit
        Anbindung, Kartentyp, MAC-Adresse, Kabelstatus und NAT-Portweiterleitungen.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Adapter
        Gibt eine oder mehrere Adapternummern an. Standardmäßig werden alle Adapter zurückgegeben.
    .PARAMETER IncludeDisabled
        Gibt auch Adapter vom Typ none zurück.
    .EXAMPLE
        Get-VBoxVMNetworkAdapter 'srv01'

        Adapter einer VM anzeigen.
        VMName Adapter Type    AttachedTo MacAddress        CableConnected
        ------ ------- ----    ---------- ----------        --------------
        srv01        1 nat                08:00:27:AA:BB:CC           True
        srv01        2 bridged eth0       08:00:27:DD:EE:FF           True
    .EXAMPLE
        Get-VBoxVM | Get-VBoxVMNetworkAdapter | Select-Object VMName, Adapter, MacAddress

        MAC-Adressen aller VMs.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.NetworkAdapter
        Objekt mit VMName, Adapter, Type, AttachedTo, NicType, MacAddress, CableConnected und
        PortForwarding.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage showvminfo <vm> --machinereadable
    .LINK
        Set-VBoxVMNetworkAdapter
    .LINK
        Get-VBoxNatPortForward
    #>
    [CmdletBinding()]
    [OutputType('VBoxPS.NetworkAdapter')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [int[]]$Adapter,
        [switch]$IncludeDisabled
    )
    process {
        $lines = Get-VBoxVMInfoLines -Name $Name
        $info  = ConvertFrom-VBoxMachineReadable -Line $lines
        $rules = @(Get-VBoxNatRuleFromLine -VMName $Name -Line $lines)
        $attachKeys = @{
            bridged    = @('bridgeadapter')
            hostonly   = @('hostonlyadapter')
            intnet     = @('intnet')
            natnetwork = @('nat-network', 'natnetwork')
            generic    = @('generic')
        }
        $numbers = @($info.Keys | Where-Object { $_ -match '^nic\d+$' } | ForEach-Object { [int]($_ -replace '^nic', '') } | Sort-Object)
        foreach ($n in $numbers) {
            if ($Adapter -and $Adapter -notcontains $n) { continue }
            $type = $info["nic$n"]
            if ($type -eq 'none' -and -not $IncludeDisabled) { continue }
            $attached = $null
            if ($attachKeys.ContainsKey($type)) {
                foreach ($k in $attachKeys[$type]) { if ($info["$k$n"]) { $attached = $info["$k$n"]; break } }
            }
            [pscustomobject]@{
                PSTypeName     = 'VBoxPS.NetworkAdapter'
                VMName         = $Name
                Adapter        = $n
                Type           = $type
                AttachedTo     = $attached
                NicType        = $info["nictype$n"]
                MacAddress     = Format-VBoxMac $info["macaddress$n"]
                CableConnected = ($info["cableconnected$n"] -eq 'on')
                PortForwarding = @($rules | Where-Object { $_.Adapter -eq $n })
            }
        }
    }
}

function Set-VBoxVMNetworkAdapter {
    <#
    .SYNOPSIS
        Konfiguriert einen Netzwerkadapter. Typ, Kabel und Promiscuous-Mode gehen auch im laufenden Betrieb.
    .DESCRIPTION
        Das Cmdlet Set-VBoxVMNetworkAdapter konfiguriert einen Netzwerkadapter.

        Typ, Anbindung, Kabelstatus und Promiscuous-Mode lassen sich auch bei laufender VM ändern.
        Kartentyp und MAC-Adresse nur bei ausgeschalteter VM. Das Cmdlet wählt automatisch modifyvm
        oder controlvm.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Adapter
        Gibt die Nummer des Netzwerkadapters an (1 = erster Adapter).
    .PARAMETER Type
        Gibt die Anbindung an: None, Null (Adapter vorhanden, aber nicht verbunden), NAT, NATNetwork,
        Bridged, HostOnly oder Internal. None ist nur bei ausgeschalteter VM möglich.
    .PARAMETER NetworkName
        Gibt das Ziel der Anbindung an: Host-Netzwerkkarte (Bridged), Host-Only-Interface (HostOnly)
        oder Netzwerkname (Internal, NATNetwork). Bei Internal ist der Standard intnet.
    .PARAMETER NicType
        Gibt den emulierten Kartentyp an, z. B. 82540EM (Intel PRO/1000 MT Desktop) oder virtio.
    .PARAMETER MacAddress
        Gibt die MAC-Adresse an, mit oder ohne Trennzeichen. auto erzeugt eine neue zufällige Adresse.
    .PARAMETER CableConnected
        Steckt das virtuelle Netzwerkkabel ein ($true) oder aus ($false).
    .PARAMETER PromiscuousMode
        Gibt den Promiscuous-Mode an: Deny, AllowVMs oder AllowAll.
    .PARAMETER PassThru
        Gibt den geänderten Adapter als VBoxPS.NetworkAdapter-Objekt zurück.
    .EXAMPLE
        Set-VBoxVMNetworkAdapter 'Win11-Lab' -Adapter 2 -Type Internal -NetworkName 'LabNet'

        Zweiten Adapter an ein internes Netz hängen.
    .EXAMPLE
        Set-VBoxVMNetworkAdapter 'Win11-Lab' -Adapter 1 -CableConnected $false

        Kabel im laufenden Betrieb ziehen.
        Praktisch, um Netzwerkausfälle zu testen.
    .EXAMPLE
        Set-VBoxVMNetworkAdapter 'srv01' -Adapter 1 -NicType virtio -MacAddress '08-00-27-12-34-56'

        Feste MAC und virtio-Karte setzen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .OUTPUTS
        VBoxPS.NetworkAdapter
        Mit -PassThru.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage modifyvm (VM aus) bzw. controlvm (VM läuft)
    .LINK
        Get-VBoxVMNetworkAdapter
    .LINK
        Get-VBoxBridgedInterface
    .LINK
        Get-VBoxHostOnlyInterface
    .LINK
        Get-VBoxNatNetwork
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, 36)]
        [int]$Adapter,
        [ValidateSet('None', 'Null', 'NAT', 'NATNetwork', 'Bridged', 'HostOnly', 'Internal')]
        [string]$Type,
        [string]$NetworkName,
        [ValidateSet('Am79C970A', 'Am79C973', 'Am79C960', '82540EM', '82543GC', '82545EM', 'virtio')]
        [string]$NicType,
        [string]$MacAddress,
        [bool]$CableConnected,
        [ValidateSet('Deny', 'AllowVMs', 'AllowAll')]
        [string]$PromiscuousMode,
        [switch]$PassThru
    )
    process {
        $p = $PSBoundParameters
        if ($Type -in 'Bridged', 'HostOnly', 'NATNetwork' -and -not $NetworkName) { throw "-Type $Type erfordert -NetworkName." }
        $promisc = @{ Deny = 'deny'; AllowVMs = 'allow-vms'; AllowAll = 'allow-all' }
        $calls = New-Object System.Collections.Generic.List[object]

        if (Test-VBoxVMOnline -Name $Name) {
            if ($p.ContainsKey('NicType') -or $p.ContainsKey('MacAddress')) {
                throw 'NicType und MacAddress können nur bei ausgeschalteter VM geändert werden.'
            }
            if ($Type) {
                if ($Type -eq 'None') { throw "Typ 'None' ist im laufenden Betrieb nicht möglich – 'Null' oder -CableConnected `$false verwenden." }
                $map = @{ Null = 'null'; NAT = 'nat'; NATNetwork = 'natnetwork'; Bridged = 'bridged'; HostOnly = 'hostonly'; Internal = 'intnet' }
                $c = @('controlvm', $Name, "nic$Adapter", $map[$Type])
                if ($Type -eq 'Internal') { $c += $(if ($NetworkName) { $NetworkName } else { 'intnet' }) }
                elseif ($NetworkName -and $Type -ne 'NAT' -and $Type -ne 'Null') { $c += $NetworkName }
                $calls.Add($c)
            }
            if ($p.ContainsKey('CableConnected')) { $calls.Add(@('controlvm', $Name, "setlinkstate$Adapter", (ConvertTo-VBoxOnOff $CableConnected))) }
            if ($PromiscuousMode) { $calls.Add(@('controlvm', $Name, "nicpromisc$Adapter", $promisc[$PromiscuousMode])) }
        }
        else {
            $c = @('modifyvm', $Name)
            if ($Type)    { $c += Get-VBoxNicArgument -Adapter $Adapter -Type $Type -NetworkName $NetworkName }
            if ($NicType) { $c += "--nictype$Adapter", $NicType }
            if ($MacAddress) {
                $mac = if ($MacAddress -eq 'auto') { 'auto' } else { ($MacAddress -replace '[^0-9A-Fa-f]', '').ToUpperInvariant() }
                if ($mac -ne 'auto' -and $mac.Length -ne 12) { throw "Ungültige MAC-Adresse: $MacAddress" }
                $c += "--macaddress$Adapter", $mac
            }
            if ($p.ContainsKey('CableConnected')) { $c += "--cableconnected$Adapter", (ConvertTo-VBoxOnOff $CableConnected) }
            if ($PromiscuousMode) { $c += "--nicpromisc$Adapter", $promisc[$PromiscuousMode] }
            if ($c.Count -gt 2) { $calls.Add($c) }
        }

        if ($calls.Count -eq 0) { Write-Warning 'Keine Änderungen angegeben.'; return }
        if ($PSCmdlet.ShouldProcess("$Name / Adapter $Adapter", 'Netzwerkadapter konfigurieren')) {
            foreach ($c in $calls) { $null = Invoke-VBoxManageCore -ArgumentList $c }
            if ($PassThru) { Get-VBoxVMNetworkAdapter -Name $Name -Adapter $Adapter -IncludeDisabled }
        }
    }
}

function Get-VBoxNatPortForward {
    <#
    .SYNOPSIS
        Listet NAT-Portweiterleitungen einer VM.
    .DESCRIPTION
        Das Cmdlet Get-VBoxNatPortForward gibt die NAT-Portweiterleitungen einer VM zurück.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Adapter
        Gibt nur Regeln dieses Adapters zurück. Standardmäßig werden alle Adapter berücksichtigt.
    .EXAMPLE
        Get-VBoxNatPortForward 'srv01'

        Regeln anzeigen.
        VMName Adapter RuleName Protocol HostIP    HostPort GuestIP GuestPort
        ------ ------- -------- -------- ------    -------- ------- ---------
        srv01        1 ssh      TCP                    2222                22
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.NatPortForward
        Objekt mit VMName, Adapter, RuleName, Protocol, HostIP, HostPort, GuestIP und GuestPort.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage showvminfo <vm> --machinereadable
    .LINK
        Add-VBoxNatPortForward
    .LINK
        Remove-VBoxNatPortForward
    #>
    [CmdletBinding()]
    [OutputType('VBoxPS.NatPortForward')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [int]$Adapter
    )
    process {
        Get-VBoxNatRuleFromLine -VMName $Name -Line (Get-VBoxVMInfoLines -Name $Name) |
            Where-Object { -not $Adapter -or $_.Adapter -eq $Adapter }
    }
}

function Add-VBoxNatPortForward {
    <#
    .SYNOPSIS
        Legt eine NAT-Portweiterleitung an (auch bei laufender VM).
    .DESCRIPTION
        Das Cmdlet Add-VBoxNatPortForward legt eine Portweiterleitung für einen NAT-Adapter an. Das
        funktioniert auch bei laufender VM.

        Ohne -RuleName wird der Name aus Protokoll und Host-Port gebildet, z. B. tcp-2222.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Adapter
        Gibt die Nummer des Netzwerkadapters an (1 = erster Adapter).
    .PARAMETER RuleName
        Gibt den Namen der Regel an. Kommas sind nicht erlaubt.
    .PARAMETER Protocol
        Gibt das Protokoll an: TCP oder UDP.
    .PARAMETER HostIP
        Gibt die Host-Adresse an, auf der gelauscht wird. Leer bedeutet alle Adressen. Mit 127.0.0.1
        ist der Port nur lokal erreichbar.
    .PARAMETER HostPort
        Gibt den Port auf dem Host an.
    .PARAMETER GuestIP
        Gibt die Zieladresse im Gast an. Leer bedeutet die per DHCP vergebene Adresse.
    .PARAMETER GuestPort
        Gibt den Zielport im Gast an.
    .EXAMPLE
        Add-VBoxNatPortForward 'srv01' -HostPort 2222 -GuestPort 22 -RuleName ssh
        ssh -p 2222 admin@localhost

        SSH auf Port 2222 weiterleiten.
    .EXAMPLE
        Add-VBoxNatPortForward 'Win11-Lab' -HostPort 33389 -GuestPort 3389 -HostIP 127.0.0.1

        RDP nur lokal freigeben.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.NatPortForward
        Die angelegte Regel.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage modifyvm --natpfN (VM aus) bzw. controlvm natpfN (VM
        läuft)
    .LINK
        Get-VBoxNatPortForward
    .LINK
        Remove-VBoxNatPortForward
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [ValidateRange(1, 36)][int]$Adapter = 1,
        [string]$RuleName,
        [ValidateSet('TCP', 'UDP')][string]$Protocol = 'TCP',
        [string]$HostIP = '',
        [Parameter(Mandatory)][ValidateRange(1, 65535)][int]$HostPort,
        [string]$GuestIP = '',
        [Parameter(Mandatory)][ValidateRange(1, 65535)][int]$GuestPort
    )
    process {
        if (-not $RuleName) { $RuleName = '{0}-{1}' -f $Protocol.ToLowerInvariant(), $HostPort }
        if ($RuleName -match ',') { throw 'RuleName darf kein Komma enthalten.' }
        $rule = '{0},{1},{2},{3},{4},{5}' -f $RuleName, $Protocol.ToLowerInvariant(), $HostIP, $HostPort, $GuestIP, $GuestPort
        if (-not $PSCmdlet.ShouldProcess($Name, "Portweiterleitung '$RuleName' (Host $HostPort -> Gast $GuestPort) anlegen")) { return }
        $cli = if (Test-VBoxVMOnline -Name $Name) { @('controlvm', $Name, "natpf$Adapter", $rule) } else { @('modifyvm', $Name, "--natpf$Adapter", $rule) }
        $null = Invoke-VBoxManageCore -ArgumentList $cli
        Get-VBoxNatPortForward -Name $Name -Adapter $Adapter | Where-Object RuleName -eq $RuleName
    }
}

function Remove-VBoxNatPortForward {
    <#
    .SYNOPSIS
        Entfernt eine NAT-Portweiterleitung.
    .DESCRIPTION
        Das Cmdlet Remove-VBoxNatPortForward entfernt eine NAT-Portweiterleitung, auch bei laufender
        VM.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Adapter
        Gibt die Nummer des Netzwerkadapters an (1 = erster Adapter).
    .PARAMETER RuleName
        Gibt den Namen der zu entfernenden Regel an.
    .EXAMPLE
        Remove-VBoxNatPortForward 'srv01' -RuleName ssh

        Regel entfernen.
    .EXAMPLE
        Get-VBoxNatPortForward 'srv01' | Remove-VBoxNatPortForward

        Alle Regeln einer VM entfernen.
    .INPUTS
        VBoxPS.NatPortForward
        Sie können Regeln von Get-VBoxNatPortForward übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage modifyvm --natpfN delete bzw. controlvm natpfN delete
    .LINK
        Get-VBoxNatPortForward
    .LINK
        Add-VBoxNatPortForward
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateRange(1, 36)][int]$Adapter = 1,
        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [string]$RuleName
    )
    process {
        if (-not $PSCmdlet.ShouldProcess($Name, "Portweiterleitung '$RuleName' entfernen")) { return }
        $cli = if (Test-VBoxVMOnline -Name $Name) { @('controlvm', $Name, "natpf$Adapter", 'delete', $RuleName) } else { @('modifyvm', $Name, "--natpf$Adapter", 'delete', $RuleName) }
        $null = Invoke-VBoxManageCore -ArgumentList $cli
    }
}

function Get-VBoxNatNetwork {
    <#
    .SYNOPSIS
        Listet NAT-Netzwerke.
    .DESCRIPTION
        Das Cmdlet Get-VBoxNatNetwork gibt die NAT-Netzwerke zurück. In einem NAT-Netzwerk sehen sich
        mehrere VMs gegenseitig und kommen gemeinsam ins Internet.
    .PARAMETER Name
        Filtert nach dem Netzwerknamen. Platzhalter sind zulässig.
    .EXAMPLE
        Get-VBoxNatNetwork

        NAT-Netzwerke anzeigen.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Ein Objekt pro Netzwerk mit den Eigenschaften aus list natnets (u. a. Name, Network, DHCP-
        Status).
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage list natnets
    .LINK
        New-VBoxNatNetwork
    .LINK
        Remove-VBoxNatNetwork
    .LINK
        Set-VBoxVMNetworkAdapter
    #>
    [CmdletBinding()]
    param([Parameter(Position = 0)][SupportsWildcards()][string]$Name = '*')
    foreach ($n in ConvertFrom-VBoxList -Line (Invoke-VBoxManageCore -ArgumentList 'list', 'natnets').Lines) {
        # VBox 6.x: "NetworkName", 7.x: "Name"
        if (-not $n.PSObject.Properties['Name'] -and $n.PSObject.Properties['NetworkName']) {
            $n | Add-Member -NotePropertyName Name -NotePropertyValue $n.NetworkName
        }
        if ($n.Name -like $Name) { $n }
    }
}

function New-VBoxNatNetwork {
    <#
    .SYNOPSIS
        Erstellt ein NAT-Netzwerk (mehrere VMs teilen sich ein NAT-Segment).
    .DESCRIPTION
        Das Cmdlet New-VBoxNatNetwork erstellt und aktiviert ein NAT-Netzwerk. DHCP ist standardmäßig
        eingeschaltet.
    .PARAMETER Name
        Gibt den Namen des NAT-Netzwerks an.
    .PARAMETER Network
        Gibt das Netz in CIDR-Schreibweise an, z. B. 10.10.0.0/24.
    .PARAMETER DisableDhcp
        Erstellt das Netzwerk ohne DHCP-Server.
    .PARAMETER EnableIPv6
        Aktiviert IPv6 im NAT-Netzwerk.
    .EXAMPLE
        New-VBoxNatNetwork 'LabNAT' -Network '10.10.0.0/24'
        Get-VBoxVM 'Lab-*' | ForEach-Object {
            Set-VBoxVMNetworkAdapter $_.Name -Adapter 1 -Type NATNetwork -NetworkName 'LabNAT'
        }

        Lab-Netz anlegen und VMs anbinden.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Das angelegte NAT-Netzwerk.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage natnetwork add
    .LINK
        Get-VBoxNatNetwork
    .LINK
        Remove-VBoxNatNetwork
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter(Mandatory, Position = 1)][ValidatePattern('^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$')][string]$Network,
        [switch]$DisableDhcp,
        [switch]$EnableIPv6
    )
    if (-not $PSCmdlet.ShouldProcess($Name, "NAT-Netzwerk $Network anlegen")) { return }
    $cli = @('natnetwork', 'add', '--netname', $Name, '--network', $Network, '--enable', '--dhcp', (ConvertTo-VBoxOnOff (-not $DisableDhcp)))
    if ($EnableIPv6) { $cli += '--ipv6', 'on' }
    $null = Invoke-VBoxManageCore -ArgumentList $cli
    Get-VBoxNatNetwork -Name $Name
}

function Remove-VBoxNatNetwork {
    <#
    .SYNOPSIS
        Entfernt ein NAT-Netzwerk.
    .DESCRIPTION
        Das Cmdlet Remove-VBoxNatNetwork entfernt ein NAT-Netzwerk. Das Cmdlet fragt standardmäßig
        nach einer Bestätigung.
    .PARAMETER Name
        Gibt den Namen des zu entfernenden NAT-Netzwerks an.
    .EXAMPLE
        Remove-VBoxNatNetwork 'LabNAT' -Confirm:$false

        NAT-Netzwerk entfernen.
    .INPUTS
        System.String
        Sie können Netzwerknamen oder Objekte von Get-VBoxNatNetwork übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage natnetwork remove
    .LINK
        Get-VBoxNatNetwork
    .LINK
        New-VBoxNatNetwork
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)][string]$Name)
    process {
        if ($PSCmdlet.ShouldProcess($Name, 'NAT-Netzwerk entfernen')) {
            $null = Invoke-VBoxManageCore -ArgumentList 'natnetwork', 'remove', '--netname', $Name
        }
    }
}

function Get-VBoxHostOnlyInterface {
    <#
    .SYNOPSIS
        Listet die Host-Only-Interfaces.
    .DESCRIPTION
        Das Cmdlet Get-VBoxHostOnlyInterface gibt die Host-Only-Interfaces zurück. Über ein Host-Only-
        Interface kommunizieren Host und VMs miteinander, ohne Verbindung nach außen.
    .PARAMETER Name
        Filtert nach dem Interfacenamen. Platzhalter sind zulässig.
    .EXAMPLE
        Get-VBoxHostOnlyInterface | Select-Object Name, IPAddress, NetworkMask

        Host-Only-Interfaces anzeigen.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Ein Objekt pro Interface (u. a. Name, GUID, DHCP, IPAddress, NetworkMask, Status).
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage list hostonlyifs
    .LINK
        New-VBoxHostOnlyInterface
    .LINK
        Remove-VBoxHostOnlyInterface
    #>
    [CmdletBinding()]
    param([Parameter(Position = 0)][SupportsWildcards()][string]$Name = '*')
    ConvertFrom-VBoxList -Line (Invoke-VBoxManageCore -ArgumentList 'list', 'hostonlyifs').Lines |
        Where-Object { $_.Name -like $Name }
}

function New-VBoxHostOnlyInterface {
    <#
    .SYNOPSIS
        Erstellt ein Host-Only-Interface (Windows: erfordert Administratorrechte).
    .DESCRIPTION
        Das Cmdlet New-VBoxHostOnlyInterface erstellt ein Host-Only-Interface und konfiguriert
        optional dessen IP-Adresse. Unter Windows sind dafür Administratorrechte nötig.

        Den Namen vergibt VirtualBox automatisch, z. B. VirtualBox Host-Only Ethernet Adapter #2 oder
        vboxnet1.
    .PARAMETER IPAddress
        Gibt die IPv4-Adresse des Hosts auf dem neuen Interface an.
    .PARAMETER NetMask
        Gibt die Netzmaske an.
    .EXAMPLE
        New-VBoxHostOnlyInterface -IPAddress 192.168.56.1 -NetMask 255.255.255.0

        Interface mit Adresse anlegen.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Das angelegte Interface.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage hostonlyif create / ipconfig

        Unter macOS ersetzt VirtualBox 7 Host-Only-Interfaces durch Host-Only-Netzwerke. Verwenden Sie
        dort Invoke-VBoxManage hostonlynet ....
    .LINK
        Get-VBoxHostOnlyInterface
    .LINK
        Remove-VBoxHostOnlyInterface
    .LINK
        Invoke-VBoxManage
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ipaddress]$IPAddress,
        [ipaddress]$NetMask = '255.255.255.0'
    )
    if (-not $PSCmdlet.ShouldProcess('Host', 'Host-Only-Interface anlegen')) { return }
    $r = Invoke-VBoxManageCore -ArgumentList 'hostonlyif', 'create'
    if ("$($r.StdOut)$($r.StdErr)" -notmatch "Interface '(?<n>[^']+)' was successfully created") {
        throw "Name des neuen Interfaces konnte nicht ermittelt werden: $($r.StdOut)"
    }
    $ifName = $Matches['n']
    if ($IPAddress) {
        $null = Invoke-VBoxManageCore -ArgumentList 'hostonlyif', 'ipconfig', $ifName, '--ip', $IPAddress.ToString(), '--netmask', $NetMask.ToString()
    }
    Get-VBoxHostOnlyInterface | Where-Object Name -eq $ifName
}

function Remove-VBoxHostOnlyInterface {
    <#
    .SYNOPSIS
        Entfernt ein Host-Only-Interface (Windows: erfordert Administratorrechte).
    .DESCRIPTION
        Das Cmdlet Remove-VBoxHostOnlyInterface entfernt ein Host-Only-Interface. Unter Windows sind
        dafür Administratorrechte nötig. Das Cmdlet fragt standardmäßig nach einer Bestätigung.
    .PARAMETER Name
        Gibt den Namen des zu entfernenden Interfaces an.
    .EXAMPLE
        Remove-VBoxHostOnlyInterface 'VirtualBox Host-Only Ethernet Adapter #2'

        Interface entfernen.
    .INPUTS
        System.String
        Sie können Namen oder Objekte von Get-VBoxHostOnlyInterface übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage hostonlyif remove
    .LINK
        Get-VBoxHostOnlyInterface
    .LINK
        New-VBoxHostOnlyInterface
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)][string]$Name)
    process {
        if ($PSCmdlet.ShouldProcess($Name, 'Host-Only-Interface entfernen')) {
            $null = Invoke-VBoxManageCore -ArgumentList 'hostonlyif', 'remove', $Name
        }
    }
}

function Get-VBoxBridgedInterface {
    <#
    .SYNOPSIS
        Listet die Host-Netzwerkkarten, die für Bridged Networking verfügbar sind.
    .DESCRIPTION
        Das Cmdlet Get-VBoxBridgedInterface gibt die Netzwerkkarten des Hosts zurück, an die VMs im
        Bridged-Modus angebunden werden können. Den Wert der Eigenschaft Name verwenden Sie für
        -NetworkName.
    .EXAMPLE
        Get-VBoxBridgedInterface | Where-Object Status -eq 'Up' | Select-Object Name, IPAddress

        Aktive Karten anzeigen.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Ein Objekt pro Netzwerkkarte (u. a. Name, GUID, IPAddress, HardwareAddress, MediumType,
        Status).
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage list bridgedifs
    .LINK
        Set-VBoxVMNetworkAdapter
    .LINK
        New-VBoxVM
    #>
    [CmdletBinding()]
    param()
    ConvertFrom-VBoxList -Line (Invoke-VBoxManageCore -ArgumentList 'list', 'bridgedifs').Lines
}
