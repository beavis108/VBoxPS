function Get-VBoxStorageController {
    <#
    .SYNOPSIS
        Listet die Storage-Controller einer VM.
    .DESCRIPTION
        Das Cmdlet Get-VBoxStorageController gibt die Storage-Controller einer VM zurück.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .EXAMPLE
        Get-VBoxStorageController 'srv01'

        Controller anzeigen.
        VMName ControllerName Type      PortCount Bootable
        ------ -------------- ----      --------- --------
        srv01  SATA           IntelAhci         2     True
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.StorageController
        Objekt mit VMName, ControllerName, Type, PortCount und Bootable.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage showvminfo <vm> --machinereadable
    .LINK
        Add-VBoxStorageController
    .LINK
        Get-VBoxStorageAttachment
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name
    )
    process {
        $info = Get-VBoxVMInfo -Name $Name
        for ($i = 0; $null -ne $info["storagecontrollername$i"]; $i++) {
            [pscustomobject]@{
                PSTypeName     = 'VBoxPS.StorageController'
                VMName         = $Name
                ControllerName = $info["storagecontrollername$i"]
                Type           = $info["storagecontrollertype$i"]
                PortCount      = ConvertTo-VBoxInt $info["storagecontrollerportcount$i"]
                Bootable       = ($info["storagecontrollerbootable$i"] -eq 'on')
            }
        }
    }
}

function Get-VBoxStorageAttachment {
    <#
    .SYNOPSIS
        Listet die an eine VM angeschlossenen Medien (Festplatten, DVD-Laufwerke, ISOs).
    .DESCRIPTION
        Das Cmdlet Get-VBoxStorageAttachment gibt die angeschlossenen Laufwerke und Medien einer VM
        zurück.

        Die Eigenschaft Kind (HDD, DVD, Floppy) wird aus der Dateiendung abgeleitet. Ein leeres DVD-
        Laufwerk hat das Medium emptydrive.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER IncludeEmptyPorts
        Gibt auch Ports ohne angeschlossenes Gerät zurück.
    .EXAMPLE
        Get-VBoxStorageAttachment 'srv01'

        Laufwerke anzeigen.
        VMName ControllerName Port Device Kind Medium
        ------ -------------- ---- ------ ---- ------
        srv01  SATA              0      0 HDD  E:\VMs\srv01\srv01.vdi
        srv01  SATA              1      0 DVD  emptydrive
    .EXAMPLE
        Get-VBoxVM | Get-VBoxStorageAttachment | Where-Object Kind -eq 'HDD' |
            ForEach-Object { Get-Item $_.Medium } | Measure-Object Length -Sum

        Belegte Plattengröße aller VMs.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.StorageAttachment
        Objekt mit VMName, ControllerName, Port, Device, Kind, Medium und MediumUUID.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage showvminfo <vm> --machinereadable
    .LINK
        Add-VBoxStorageAttachment
    .LINK
        Remove-VBoxStorageAttachment
    .LINK
        Mount-VBoxIso
    #>
    [CmdletBinding()]
    [OutputType('VBoxPS.StorageAttachment')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [switch]$IncludeEmptyPorts
    )
    process {
        $info = Get-VBoxVMInfo -Name $Name
        for ($i = 0; $null -ne $info["storagecontrollername$i"]; $i++) {
            $ctl     = $info["storagecontrollername$i"]
            $pattern = '^{0}-(?<port>\d+)-(?<dev>\d+)$' -f [regex]::Escape($ctl)
            foreach ($key in @($info.Keys)) {
                if ($key -notmatch $pattern) { continue }
                $port   = [int]$Matches['port']
                $dev    = [int]$Matches['dev']
                $medium = $info[$key]
                if ($medium -eq 'none' -and -not $IncludeEmptyPorts) { continue }
                $kind = switch -Regex ($medium) {
                    '^none$'                                      { 'None'; break }
                    '^emptydrive$'                                { 'DVD'; break }
                    '\.(iso|dmg|cdr)$'                            { 'DVD'; break }
                    '\.(vdi|vmdk|vhd|vhdx|hdd|qcow2?|qed|parallels)$' { 'HDD'; break }
                    '\.(img|ima|vfd|flp)$'                        { 'Floppy'; break }
                    default                                       { 'Unknown' }
                }
                [pscustomobject]@{
                    PSTypeName     = 'VBoxPS.StorageAttachment'
                    VMName         = $Name
                    ControllerName = $ctl
                    Port           = $port
                    Device         = $dev
                    Kind           = $kind
                    Medium         = $medium
                    MediumUUID     = $info["$ctl-ImageUUID-$port-$dev"]
                }
            }
        }
    }
}

function Add-VBoxStorageController {
    <#
    .SYNOPSIS
        Fügt einer VM einen Storage-Controller hinzu.
    .DESCRIPTION
        Das Cmdlet Add-VBoxStorageController fügt einer VM einen Storage-Controller hinzu und gibt ihn
        zurück. Ohne -ControllerType wird der übliche Chipsatz des Bustyps verwendet.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER ControllerName
        Gibt den Namen des neuen Controllers an.
    .PARAMETER Bus
        Gibt den Bustyp an: SATA, IDE, SCSI, SAS, VirtioSCSI, NVMe, Floppy oder USB.
    .PARAMETER ControllerType
        Gibt den Chipsatz an, z. B. IntelAhci, PIIX4, LsiLogic, BusLogic, LSILogicSAS, VirtIO, NVMe.
        Standard ist der übliche Typ des Busses.
    .PARAMETER PortCount
        Gibt die Anzahl der Ports an.
    .PARAMETER Bootable
        Kennzeichnet den Controller als bootfähig.
    .PARAMETER HostIOCache
        Aktiviert den Host-I/O-Cache für diesen Controller.
    .EXAMPLE
        Add-VBoxStorageController 'srv01' -ControllerName NVMe -Bus NVMe -PortCount 2

        NVMe-Controller hinzufügen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.StorageController
        Der neue Controller.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage storagectl <vm> --add
    .LINK
        Get-VBoxStorageController
    .LINK
        Remove-VBoxStorageController
    .LINK
        Add-VBoxStorageAttachment
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory)][string]$ControllerName,
        [ValidateSet('SATA', 'IDE', 'SCSI', 'SAS', 'VirtioSCSI', 'NVMe', 'Floppy', 'USB')]
        [string]$Bus = 'SATA',
        [string]$ControllerType,
        [ValidateRange(1, 30)][int]$PortCount,
        [switch]$Bootable,
        [switch]$HostIOCache
    )
    process {
        $busMap  = @{ SATA = 'sata'; IDE = 'ide'; SCSI = 'scsi'; SAS = 'sas'; VirtioSCSI = 'virtio-scsi'; NVMe = 'pcie'; Floppy = 'floppy'; USB = 'usb' }
        $ctlMap  = @{ SATA = 'IntelAhci'; IDE = 'PIIX4'; SCSI = 'LsiLogic'; SAS = 'LSILogicSAS'; VirtioSCSI = 'VirtIO'; NVMe = 'NVMe'; Floppy = 'I82078'; USB = 'USB' }
        if (-not $ControllerType) { $ControllerType = $ctlMap[$Bus] }
        $cli = @('storagectl', $Name, '--name', $ControllerName, '--add', $busMap[$Bus], '--controller', $ControllerType)
        if ($PortCount)   { $cli += '--portcount', $PortCount }
        if ($Bootable)    { $cli += '--bootable', 'on' }
        if ($HostIOCache) { $cli += '--hostiocache', 'on' }
        if ($PSCmdlet.ShouldProcess($Name, "Controller '$ControllerName' ($Bus) hinzufügen")) {
            $null = Invoke-VBoxManageCore -ArgumentList $cli
            Get-VBoxStorageController -Name $Name | Where-Object ControllerName -eq $ControllerName
        }
    }
}

function Remove-VBoxStorageController {
    <#
    .SYNOPSIS
        Entfernt einen Storage-Controller (angeschlossene Medien werden getrennt, nicht gelöscht).
    .DESCRIPTION
        Das Cmdlet Remove-VBoxStorageController entfernt einen Storage-Controller. Angeschlossene
        Medien werden getrennt, aber nicht gelöscht. Das Cmdlet fragt standardmäßig nach einer
        Bestätigung.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER ControllerName
        Gibt den Namen des zu entfernenden Controllers an.
    .EXAMPLE
        Remove-VBoxStorageController 'srv01' -ControllerName IDE

        IDE-Controller entfernen.
    .INPUTS
        VBoxPS.StorageController
        Sie können Objekte von Get-VBoxStorageController übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage storagectl <vm> --remove
    .LINK
        Get-VBoxStorageController
    .LINK
        Add-VBoxStorageController
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [string]$ControllerName
    )
    process {
        if ($PSCmdlet.ShouldProcess($Name, "Controller '$ControllerName' entfernen")) {
            $null = Invoke-VBoxManageCore -ArgumentList 'storagectl', $Name, '--name', $ControllerName, '--remove'
        }
    }
}

function Add-VBoxStorageAttachment {
    <#
    .SYNOPSIS
        Schließt eine Festplatte, ein DVD-Laufwerk oder ein Diskettenlaufwerk an.
    .DESCRIPTION
        Das Cmdlet Add-VBoxStorageAttachment schließt eine Festplatte, ein DVD-Laufwerk oder ein
        Diskettenlaufwerk an einen Controller an.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER ControllerName
        Gibt den Namen des Storage-Controllers an, z. B. SATA.
    .PARAMETER Port
        Gibt die Portnummer am Controller an.
    .PARAMETER Device
        Gibt die Gerätenummer am Port an. Bei SATA immer 0, bei IDE 0 (Master) oder 1 (Slave).
    .PARAMETER Type
        Gibt den Gerätetyp an: HDD, DVD oder Floppy.
    .PARAMETER Medium
        Gibt die Image-Datei an. Sonderwerte: emptydrive (leeres Laufwerk), additions (Guest-
        Additions-ISO), none (Gerät entfernen).
    .PARAMETER NonRotational
        Meldet die Platte dem Gast als SSD.
    .PARAMETER Discard
        Aktiviert TRIM/Discard, damit freigegebener Platz im Image zurückgewonnen werden kann.
    .PARAMETER HotPluggable
        Kennzeichnet das Gerät als Hot-Plug-fähig.
    .EXAMPLE
        New-VBoxDisk 'E:\VMs\srv01\data.vdi' -SizeGB 100
        Add-VBoxStorageAttachment 'srv01' -ControllerName SATA -Port 2 -Type HDD -Medium 'E:\VMs\srv01\data.vdi' -NonRotational -Discard

        Datenplatte als SSD anschließen.
        Der Controller braucht genügend Ports. Bei Bedarf erst Invoke-VBoxManage storagectl srv01
        --name SATA --portcount 4 ausführen.
    .EXAMPLE
        Add-VBoxStorageAttachment 'srv01' -ControllerName SATA -Port 1 -Type DVD -Medium emptydrive

        Leeres DVD-Laufwerk hinzufügen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage storageattach <vm> --storagectl ... --medium ...
    .LINK
        Get-VBoxStorageAttachment
    .LINK
        Remove-VBoxStorageAttachment
    .LINK
        New-VBoxDisk
    .LINK
        Mount-VBoxIso
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory)][string]$ControllerName,
        [Parameter(Mandatory)][int]$Port,
        [int]$Device = 0,
        [ValidateSet('HDD', 'DVD', 'Floppy')][string]$Type = 'HDD',
        [Parameter(Mandatory)][string]$Medium,
        [switch]$NonRotational,
        [switch]$Discard,
        [switch]$HotPluggable
    )
    process {
        $typeMap = @{ HDD = 'hdd'; DVD = 'dvddrive'; Floppy = 'fdd' }
        if ($Medium -notin 'emptydrive', 'additions', 'none') { $Medium = Resolve-VBoxHostPath $Medium }
        $cli = @('storageattach', $Name, '--storagectl', $ControllerName, '--port', $Port, '--device', $Device,
            '--type', $typeMap[$Type], '--medium', $Medium)
        if ($NonRotational) { $cli += '--nonrotational', 'on' }
        if ($Discard)       { $cli += '--discard', 'on' }
        if ($HotPluggable)  { $cli += '--hotpluggable', 'on' }
        if ($PSCmdlet.ShouldProcess($Name, "$Type an ${ControllerName}:$Port/$Device anschließen")) {
            $null = Invoke-VBoxManageCore -ArgumentList $cli
        }
    }
}

function Remove-VBoxStorageAttachment {
    <#
    .SYNOPSIS
        Trennt ein Gerät vom Controller (die Image-Datei bleibt erhalten).
    .DESCRIPTION
        Das Cmdlet Remove-VBoxStorageAttachment trennt ein Gerät vom Controller. Die Image-Datei
        bleibt erhalten und registriert. Zum Löschen verwenden Sie anschließend Remove-VBoxDisk.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER ControllerName
        Gibt den Namen des Storage-Controllers an, z. B. SATA.
    .PARAMETER Port
        Gibt die Portnummer am Controller an.
    .PARAMETER Device
        Gibt die Gerätenummer am Port an. Bei SATA immer 0, bei IDE 0 (Master) oder 1 (Slave).
    .EXAMPLE
        Get-VBoxStorageAttachment 'srv01' | Where-Object Port -eq 2 | Remove-VBoxStorageAttachment

        Datenplatte trennen.
    .INPUTS
        VBoxPS.StorageAttachment
        Sie können Objekte von Get-VBoxStorageAttachment übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage storageattach <vm> ... --medium none
    .LINK
        Get-VBoxStorageAttachment
    .LINK
        Add-VBoxStorageAttachment
    .LINK
        Remove-VBoxDisk
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)][string]$ControllerName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)][int]$Port,
        [Parameter(ValueFromPipelineByPropertyName)][int]$Device = 0
    )
    process {
        if ($PSCmdlet.ShouldProcess($Name, "Gerät an ${ControllerName}:$Port/$Device trennen")) {
            $null = Invoke-VBoxManageCore -ArgumentList 'storageattach', $Name, '--storagectl', $ControllerName,
                '--port', $Port, '--device', $Device, '--medium', 'none'
        }
    }
}

function Mount-VBoxIso {
    <#
    .SYNOPSIS
        Legt ein ISO in das (erste) DVD-Laufwerk der VM ein – auch im laufenden Betrieb.
    .DESCRIPTION
        Das Cmdlet Mount-VBoxIso legt eine ISO-Datei in ein DVD-Laufwerk der VM ein. Das funktioniert
        auch bei laufender VM.

        Ohne -ControllerName und -Port verwendet das Cmdlet das erste vorhandene DVD-Laufwerk. Ein
        bereits eingelegtes ISO wird ersetzt.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER IsoPath
        Gibt den Pfad zur ISO-Datei an. Mit additions wird die Guest-Additions-ISO eingelegt.
    .PARAMETER ControllerName
        Gibt den Controller des DVD-Laufwerks an. Standard ist das erste gefundene DVD-Laufwerk.
    .PARAMETER Port
        Gibt den Port des DVD-Laufwerks an. Standard ist das erste gefundene DVD-Laufwerk.
    .PARAMETER Device
        Gibt die Gerätenummer am Port an. Bei SATA immer 0, bei IDE 0 (Master) oder 1 (Slave).
    .PARAMETER Force
        Erzwingt das Auswerfen, auch wenn der Gast das Laufwerk gesperrt hat.
    .EXAMPLE
        Mount-VBoxIso 'Win11-Lab' 'D:\ISO\virtio-win.iso'

        Treiber-ISO einlegen.
    .EXAMPLE
        Mount-VBoxIso 'Win11-Lab' additions -Force

        Guest Additions einlegen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage storageattach <vm> ... --type dvddrive --medium <iso>
    .LINK
        Dismount-VBoxIso
    .LINK
        Get-VBoxStorageAttachment
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory, Position = 1)][string]$IsoPath,
        [string]$ControllerName,
        [int]$Port = -1,
        [int]$Device = 0,
        [switch]$Force
    )
    process {
        if ($IsoPath -ne 'additions') {
            $IsoPath = Resolve-VBoxHostPath $IsoPath
            if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) { throw "ISO nicht gefunden: $IsoPath" }
        }
        if (-not $ControllerName -or $Port -lt 0) {
            $drive = Get-VBoxStorageAttachment -Name $Name | Where-Object Kind -eq 'DVD' | Select-Object -First 1
            if (-not $drive) { throw "VM '$Name' hat kein DVD-Laufwerk. Mit Add-VBoxStorageAttachment -Type DVD -Medium emptydrive anlegen." }
            $ControllerName = $drive.ControllerName; $Port = $drive.Port; $Device = $drive.Device
        }
        $cli = @('storageattach', $Name, '--storagectl', $ControllerName, '--port', $Port, '--device', $Device,
            '--type', 'dvddrive', '--medium', $IsoPath)
        if ($Force) { $cli += '--forceunmount' }
        if ($PSCmdlet.ShouldProcess($Name, "ISO '$IsoPath' einlegen (${ControllerName}:$Port/$Device)")) {
            $null = Invoke-VBoxManageCore -ArgumentList $cli
        }
    }
}

function Dismount-VBoxIso {
    <#
    .SYNOPSIS
        Wirft eingelegte ISOs aus (das DVD-Laufwerk bleibt erhalten).
    .DESCRIPTION
        Das Cmdlet Dismount-VBoxIso wirft alle eingelegten ISO-Dateien aus. Die DVD-Laufwerke bleiben
        erhalten.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Force
        Erzwingt das Auswerfen, auch wenn der Gast das Laufwerk gesperrt hat.
    .EXAMPLE
        Dismount-VBoxIso 'Win11-Lab'

        ISO nach der Installation auswerfen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage storageattach <vm> ... --medium emptydrive
    .LINK
        Mount-VBoxIso
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [switch]$Force
    )
    process {
        $drives = @(Get-VBoxStorageAttachment -Name $Name | Where-Object { $_.Kind -eq 'DVD' -and $_.Medium -ne 'emptydrive' })
        foreach ($d in $drives) {
            if (-not $PSCmdlet.ShouldProcess($Name, "ISO '$($d.Medium)' auswerfen")) { continue }
            $cli = @('storageattach', $Name, '--storagectl', $d.ControllerName, '--port', $d.Port, '--device', $d.Device,
                '--type', 'dvddrive', '--medium', 'emptydrive')
            if ($Force) { $cli += '--forceunmount' }
            $null = Invoke-VBoxManageCore -ArgumentList $cli
        }
    }
}

function Get-VBoxDisk {
    <#
    .SYNOPSIS
        Listet alle bei VirtualBox registrierten Festplatten-Images.
    .DESCRIPTION
        Das Cmdlet Get-VBoxDisk gibt alle bei VirtualBox registrierten Festplatten-Images zurück. Die
        Eigenschaft SizeMB enthält die Kapazität als Zahl.
    .PARAMETER Path
        Filtert nach dem Pfad (Location) oder der UUID. Platzhalter sind zulässig.
    .EXAMPLE
        Get-VBoxDisk | Select-Object Location, SizeMB, State

        Alle Images mit Größe.
    .EXAMPLE
        Get-VBoxDisk 'E:\VMs\srv01\*'

        Images eines Ordners.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Ein Objekt pro Image (u. a. UUID, ParentUUID, State, Type, Location, StorageFormat, Capacity,
        SizeMB).
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage list hdds
    .LINK
        New-VBoxDisk
    .LINK
        Resize-VBoxDisk
    .LINK
        Remove-VBoxDisk
    #>
    [CmdletBinding()]
    param([Parameter(Position = 0)][SupportsWildcards()][string]$Path = '*')
    foreach ($d in ConvertFrom-VBoxList -Line (Invoke-VBoxManageCore -ArgumentList 'list', 'hdds').Lines) {
        $size = $null
        if ($d.PSObject.Properties['Capacity'] -and $d.Capacity -match '^(?<n>\d+)\s*MB') { $size = [int64]$Matches['n'] }
        $d | Add-Member -NotePropertyName SizeMB -NotePropertyValue $size -Force
        if ($d.Location -like $Path -or $d.UUID -eq $Path) { $d }
    }
}

function New-VBoxDisk {
    <#
    .SYNOPSIS
        Erstellt ein neues Festplatten-Image.
    .DESCRIPTION
        Das Cmdlet New-VBoxDisk erstellt ein neues Festplatten-Image. Standardmäßig wächst die Datei
        dynamisch bis zur angegebenen Größe.
    .PARAMETER Path
        Gibt den Pfad der neuen Image-Datei an. Die Datei darf noch nicht existieren.
    .PARAMETER SizeGB
        Gibt die Größe in GB an.
    .PARAMETER Format
        Gibt das Format an: VDI (VirtualBox), VMDK (VMware) oder VHD (Hyper-V).
    .PARAMETER Fixed
        Reserviert den gesamten Platz sofort. Das ist etwas schneller im Betrieb, belegt aber sofort
        den vollen Speicher.
    .EXAMPLE
        New-VBoxDisk 'E:\VMs\srv01\data.vdi' -SizeGB 100

        Datenplatte erstellen.
        Path   : E:\VMs\srv01\data.vdi
        UUID   : 6f1c...
        SizeGB : 100
        Format : VDI
        Fixed  : False
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Objekt mit Path, UUID, SizeGB, Format und Fixed.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage createmedium disk
    .LINK
        Add-VBoxStorageAttachment
    .LINK
        Resize-VBoxDisk
    .LINK
        Get-VBoxDisk
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Path,
        [Parameter(Mandatory, Position = 1)][ValidateRange(1, 65536)][int]$SizeGB,
        [ValidateSet('VDI', 'VMDK', 'VHD')][string]$Format = 'VDI',
        [switch]$Fixed
    )
    $Path = Resolve-VBoxHostPath $Path
    if (Test-Path -LiteralPath $Path) { throw "Datei existiert bereits: $Path" }
    if (-not $PSCmdlet.ShouldProcess($Path, "Festplatte ($SizeGB GB, $Format) erstellen")) { return }
    $cli = @('createmedium', 'disk', '--filename', $Path, '--size', ([int64]$SizeGB * 1024), '--format', $Format)
    if ($Fixed) { $cli += '--variant', 'Fixed' }
    $r = Invoke-VBoxManageCore -ArgumentList $cli
    $uuid = $null
    if ($r.StdOut -match 'UUID:\s*(?<u>[0-9a-fA-F-]{36})') { $uuid = $Matches['u'] }
    [pscustomobject]@{ Path = $Path; UUID = $uuid; SizeGB = $SizeGB; Format = $Format; Fixed = [bool]$Fixed }
}

function Resize-VBoxDisk {
    <#
    .SYNOPSIS
        Vergrößert ein Festplatten-Image (Partition im Gast anschließend erweitern).
    .DESCRIPTION
        Das Cmdlet Resize-VBoxDisk vergrößert ein Festplatten-Image. Verkleinern ist nicht möglich.
        Die Partition im Gast müssen Sie anschließend selbst erweitern.

        Unterstützt werden VDI- und VHD-Images mit dynamischer Größe.
    .PARAMETER Path
        Gibt den Pfad oder die UUID des Images an.
    .PARAMETER SizeGB
        Gibt die neue Gesamtgröße in GB an.
    .EXAMPLE
        Resize-VBoxDisk 'E:\VMs\srv01\srv01.vdi' -SizeGB 120

        Systemplatte auf 120 GB vergrößern.
    .EXAMPLE
        $cmd = 'Resize-Partition -DriveLetter C -Size (Get-PartitionSupportedSize -DriveLetter C).SizeMax'
        Invoke-VBoxGuestCommand 'Win11-Lab' -Credential $cred `
            -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ArgumentList '-Command', $cmd

        Danach im Windows-Gast erweitern.
    .INPUTS
        System.String
        Sie können Pfade oder Objekte von Get-VBoxDisk übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage modifymedium disk <pfad> --resize <MB>
    .LINK
        Get-VBoxDisk
    .LINK
        New-VBoxDisk
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Location')]
        [string]$Path,
        [Parameter(Mandatory, Position = 1)][ValidateRange(1, 65536)][int]$SizeGB
    )
    process {
        if ($Path -notmatch '^[0-9a-fA-F-]{36}$') { $Path = Resolve-VBoxHostPath $Path }
        if ($PSCmdlet.ShouldProcess($Path, "Auf $SizeGB GB vergrößern")) {
            $null = Invoke-VBoxManageCore -ArgumentList 'modifymedium', 'disk', $Path, '--resize', ([int64]$SizeGB * 1024)
        }
    }
}

function Remove-VBoxDisk {
    <#
    .SYNOPSIS
        Entfernt ein Festplatten-Image aus der VirtualBox-Registrierung und löscht es optional.
    .DESCRIPTION
        Das Cmdlet Remove-VBoxDisk entfernt ein Festplatten-Image aus der VirtualBox-Registrierung.
        Mit -DeleteFile wird auch die Datei gelöscht. Das Cmdlet fragt standardmäßig nach einer
        Bestätigung.

        Das Image darf an keine VM angeschlossen sein.
    .PARAMETER Path
        Gibt den Pfad oder die UUID des Images an.
    .PARAMETER DeleteFile
        Löscht zusätzlich die Image-Datei.
    .EXAMPLE
        Remove-VBoxDisk 'E:\VMs\alt\data.vdi' -DeleteFile

        Image deregistrieren und löschen.
    .INPUTS
        System.String
        Sie können Pfade oder Objekte von Get-VBoxDisk übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage closemedium disk <pfad> [--delete]
    .LINK
        Get-VBoxDisk
    .LINK
        Remove-VBoxStorageAttachment
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Location')]
        [string]$Path,
        [switch]$DeleteFile
    )
    process {
        if ($Path -notmatch '^[0-9a-fA-F-]{36}$') { $Path = Resolve-VBoxHostPath $Path }
        $what = if ($DeleteFile) { 'Festplatte deregistrieren und Datei löschen' } else { 'Festplatte deregistrieren' }
        if ($PSCmdlet.ShouldProcess($Path, $what)) {
            $cli = @('closemedium', 'disk', $Path)
            if ($DeleteFile) { $cli += '--delete' }
            $null = Invoke-VBoxManageCore -ArgumentList $cli
        }
    }
}
