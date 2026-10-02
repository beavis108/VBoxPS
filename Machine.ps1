function New-VBoxVM {
    <#
    .SYNOPSIS
        Erstellt und registriert eine neue VM inkl. SATA-Controller, optionaler Festplatte und DVD-Laufwerk.
    .DESCRIPTION
        Das Cmdlet New-VBoxVM erstellt und registriert eine neue VM und gibt sie zurück.

        Die VM erhält einen SATA-Controller SATA. Port 0 ist die Festplatte, falls -DiskSizeGB größer
        als 0 ist, Port 1 ein DVD-Laufwerk mit ISO oder leer. Die Bootreihenfolge ist DVD, dann
        Festplatte. Windows-Gäste bekommen standardmäßig den Grafikcontroller VBoxSVGA, andere VMSVGA.

        Schlägt ein Schritt nach dem Anlegen fehl, wird die halbfertige VM wieder gelöscht.
    .PARAMETER Name
        Gibt den Namen der neuen VM an. Der Name darf noch nicht vergeben sein.
    .PARAMETER OSType
        Gibt die OS-Typ-ID an, z. B. Windows11_64, Windows2022_64 oder Ubuntu_64. Eine Liste liefert
        Get-VBoxOSType, außerdem gibt es Tab-Vervollständigung.
    .PARAMETER MemoryMB
        Gibt den Arbeitsspeicher in MB an.
    .PARAMETER CPUs
        Gibt die Anzahl der virtuellen CPUs an.
    .PARAMETER VRAMMB
        Gibt den Grafikspeicher in MB an.
    .PARAMETER Firmware
        Gibt die Firmware an: BIOS oder EFI. Für Windows 11 und Secure Boot ist EFI erforderlich.
    .PARAMETER GraphicsController
        Gibt den Grafikcontroller an. Ohne Angabe wird für Windows-Gäste VBoxSVGA, sonst VMSVGA
        verwendet.
    .PARAMETER BaseFolder
        Gibt den Ordner an, in dem der VM-Ordner angelegt wird. Standard ist der VirtualBox-
        Standardordner.
    .PARAMETER Group
        Gibt eine oder mehrere VM-Gruppen an, z. B. Lab oder /Kunden/A. Ein führender / wird ergänzt.
    .PARAMETER Description
        Gibt eine Beschreibung für die VM an.
    .PARAMETER DiskSizeGB
        Gibt die Größe der Systemplatte in GB an. Bei 0 (Standard) wird keine Platte erstellt.
    .PARAMETER DiskPath
        Gibt den Pfad der Plattendatei an. Standard ist <VM-Ordner>\<Name>.<format>.
    .PARAMETER DiskFormat
        Gibt das Plattenformat an: VDI, VMDK oder VHD.
    .PARAMETER FixedDisk
        Erstellt eine Platte fester Größe statt einer dynamisch wachsenden.
    .PARAMETER IsoPath
        Gibt eine ISO-Datei an, die ins DVD-Laufwerk eingelegt wird.
    .PARAMETER NetworkType
        Gibt die Anbindung von Netzwerkadapter 1 an: NAT, NATNetwork, Bridged, HostOnly, Internal oder
        None.
    .PARAMETER NetworkName
        Gibt das Ziel der Anbindung an: bei Bridged die Host-Netzwerkkarte, bei HostOnly das Host-
        Only-Interface, bei Internal und NATNetwork den Netzwerknamen. Pflicht für Bridged, HostOnly
        und NATNetwork.
    .PARAMETER EnableTpm
        Aktiviert ein virtuelles TPM 2.0 (ab VirtualBox 7.0).
    .PARAMETER EnableSecureBoot
        Initialisiert den UEFI-Variablenspeicher, registriert die Microsoft-Signaturen und aktiviert
        Secure Boot. Erfordert -Firmware EFI und VirtualBox 7.0.
    .PARAMETER EnableNestedVirtualization
        Aktiviert verschachtelte Virtualisierung (VT-x/AMD-V im Gast), z. B. für Hyper-V oder WSL2 im
        Gast.
    .EXAMPLE
        New-VBoxVM 'Win11-Lab' -OSType Windows11_64 -MemoryMB 8192 -CPUs 4 -DiskSizeGB 80 `
            -Firmware EFI -EnableTpm -EnableSecureBoot -IsoPath 'D:\ISO\Win11_24H2.iso'

        Windows-11-VM mit TPM und Secure Boot.
    .EXAMPLE
        $nic = (Get-VBoxBridgedInterface | Where-Object Status -eq 'Up')[0].Name
        New-VBoxVM 'srv01' -OSType Ubuntu_64 -DiskSizeGB 40 -NetworkType Bridged -NetworkName $nic

        Linux-Server im Bridged-Netz.
    .EXAMPLE
        New-VBoxVM 'test' -OSType Ubuntu_64 -WhatIf

        Testlauf ohne Änderungen.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        VBoxPS.VM
        Ein Objekt mit Name, UUID, State, OSType, MemoryMB, CPUs, VRAMMB, Firmware, Groups,
        Description, ConfigFile, Directory und StateChanged.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage createvm, modifyvm, storagectl, createmedium,
        storageattach, modifynvram

        Für eine vollautomatische Installation verwenden Sie anschließend Start-VBoxUnattendedInstall.
    .LINK
        Start-VBoxUnattendedInstall
    .LINK
        Get-VBoxOSType
    .LINK
        Set-VBoxVM
    .LINK
        Copy-VBoxVM
    .LINK
        Remove-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('VBoxPS.VM')]
    param(
        [Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string]$Name,
        [Parameter(Mandatory, Position = 1)][string]$OSType,
        [ValidateRange(4, 2097152)][int]$MemoryMB = 2048,
        [ValidateRange(1, 64)][int]$CPUs = 2,
        [ValidateRange(0, 256)][int]$VRAMMB = 32,
        [ValidateSet('BIOS', 'EFI')][string]$Firmware = 'BIOS',
        [ValidateSet('VMSVGA', 'VBoxSVGA', 'VBoxVGA', 'None')][string]$GraphicsController,
        [string]$BaseFolder,
        [string[]]$Group,
        [string]$Description,
        [ValidateRange(0, 65536)][int]$DiskSizeGB = 0,
        [string]$DiskPath,
        [ValidateSet('VDI', 'VMDK', 'VHD')][string]$DiskFormat = 'VDI',
        [switch]$FixedDisk,
        [string]$IsoPath,
        [ValidateSet('NAT', 'NATNetwork', 'Bridged', 'HostOnly', 'Internal', 'None')][string]$NetworkType = 'NAT',
        [string]$NetworkName,
        [switch]$EnableTpm,
        [switch]$EnableSecureBoot,
        [switch]$EnableNestedVirtualization
    )

    if ($EnableSecureBoot -and $Firmware -ne 'EFI') { throw '-EnableSecureBoot erfordert -Firmware EFI.' }
    if ($NetworkType -in 'Bridged', 'HostOnly', 'NATNetwork' -and -not $NetworkName) { throw "-NetworkType $NetworkType erfordert -NetworkName." }
    if ($EnableTpm -or $EnableSecureBoot) { Assert-VBoxVersion -Minimum '7.0' -Feature 'TPM/Secure Boot' }
    if ($IsoPath) {
        $IsoPath = Resolve-VBoxHostPath $IsoPath
        if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) { throw "ISO nicht gefunden: $IsoPath" }
    }
    if ($DiskPath)   { $DiskPath   = Resolve-VBoxHostPath $DiskPath }
    if ($BaseFolder) { $BaseFolder = Resolve-VBoxHostPath $BaseFolder }
    if (Get-VBoxVMList | Where-Object { $_.Name -eq $Name }) { throw "Eine VM mit dem Namen '$Name' existiert bereits." }

    if (-not $PSCmdlet.ShouldProcess($Name, 'VM erstellen')) { return }

    $create = @('createvm', '--name', $Name, '--ostype', $OSType, '--register')
    if ($BaseFolder) { $create += '--basefolder', $BaseFolder }
    if ($Group) { $create += '--groups', (ConvertTo-VBoxGroupString $Group) }
    $null = Invoke-VBoxManageCore -ArgumentList $create

    try {
        $isWindowsGuest = $OSType -like 'Windows*'
        if (-not $GraphicsController) { $GraphicsController = if ($isWindowsGuest) { 'VBoxSVGA' } else { 'VMSVGA' } }

        $modify = @('modifyvm', $Name,
            '--memory', $MemoryMB, '--cpus', $CPUs, '--vram', $VRAMMB,
            '--firmware', $Firmware.ToLowerInvariant(),
            '--graphicscontroller', $GraphicsController.ToLowerInvariant(),
            '--ioapic', 'on',
            '--rtcuseutc', (ConvertTo-VBoxOnOff (-not $isWindowsGuest)),
            '--boot1', 'dvd', '--boot2', 'disk', '--boot3', 'none', '--boot4', 'none')
        $modify += Get-VBoxNicArgument -Adapter 1 -Type $NetworkType -NetworkName $NetworkName
        if ($Description) { $modify += '--description', $Description }
        if ($EnableNestedVirtualization) { $modify += '--nested-hw-virt', 'on' }
        if ($EnableTpm) { $modify += '--tpm-type', '2.0' }
        $null = Invoke-VBoxManageCore -ArgumentList $modify

        $vmDir = Split-VBoxParentPath (Get-VBoxVMInfo -Name $Name)['CfgFile']
        $null = Invoke-VBoxManageCore -ArgumentList 'storagectl', $Name, '--name', 'SATA', '--add', 'sata',
            '--controller', 'IntelAhci', '--portcount', '2', '--bootable', 'on'

        if ($DiskSizeGB -gt 0) {
            if (-not $DiskPath) {
                $DiskPath = Join-VBoxPath $vmDir ('{0}.{1}' -f $Name, $DiskFormat.ToLowerInvariant())
            }
            $null = New-VBoxDisk -Path $DiskPath -SizeGB $DiskSizeGB -Format $DiskFormat -Fixed:$FixedDisk -WhatIf:$false -Confirm:$false
            $null = Invoke-VBoxManageCore -ArgumentList 'storageattach', $Name, '--storagectl', 'SATA',
                '--port', '0', '--device', '0', '--type', 'hdd', '--medium', $DiskPath
        }

        $dvd = if ($IsoPath) { $IsoPath } else { 'emptydrive' }
        $null = Invoke-VBoxManageCore -ArgumentList 'storageattach', $Name, '--storagectl', 'SATA',
            '--port', '1', '--device', '0', '--type', 'dvddrive', '--medium', $dvd

        if ($EnableSecureBoot) {
            $null = Invoke-VBoxManageCore -ArgumentList 'modifynvram', $Name, 'inituefivarstore'
            $null = Invoke-VBoxManageCore -ArgumentList 'modifynvram', $Name, 'enrollmssignatures'
            $null = Invoke-VBoxManageCore -ArgumentList 'modifynvram', $Name, 'enrollorclkey'
            $sb = Invoke-VBoxManageCore -ArgumentList 'modifynvram', $Name, 'secureboot', '--enable' -NoThrow
            if ($sb.ExitCode -ne 0) { Write-Verbose 'modifynvram secureboot nicht verfügbar – Secure Boot ist über den Platform Key aktiv.' }
        }
    }
    catch {
        $err = $_
        Write-Warning "Erstellung von '$Name' fehlgeschlagen – entferne die unvollständige VM."
        $null = Invoke-VBoxManageCore -ArgumentList 'unregistervm', $Name, '--delete' -NoThrow
        throw $err
    }

    Get-VBoxVM -Name $Name
}

function Copy-VBoxVM {
    <#
    .SYNOPSIS
        Klont eine VM (vollständig oder als Linked Clone).
    .DESCRIPTION
        Das Cmdlet Copy-VBoxVM klont eine VM und registriert den Klon.

        Ein Linked Clone (-Linked) teilt sich die Basisplatte mit der Quelle und ist in Sekunden
        angelegt. Er benötigt einen Snapshot der Quell-VM. Ohne -SnapshotName wird der aktuelle
        Snapshot verwendet.

        Klone erhalten standardmäßig neue MAC-Adressen.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER NewName
        Gibt den Namen des Klons an.
    .PARAMETER Linked
        Erstellt einen Linked Clone auf Basis eines Snapshots.
    .PARAMETER SnapshotName
        Gibt den Snapshot (Name oder UUID) an, von dem geklont wird. Standard bei -Linked ist der
        aktuelle Snapshot.
    .PARAMETER Mode
        Gibt an, was geklont wird: Machine (nur aktueller Zustand), MachineAndChildren (ab dem
        angegebenen Snapshot inkl. Untersnapshots) oder All (inkl. aller Snapshots).
    .PARAMETER BaseFolder
        Gibt den Ordner an, in dem der Klon angelegt wird.
    .PARAMETER Group
        Gibt eine oder mehrere VM-Gruppen für den Klon an.
    .PARAMETER KeepMacAddresses
        Übernimmt die MAC-Adressen aller Adapter.
    .PARAMETER KeepDiskNames
        Behält die Dateinamen der Platten bei.
    .PARAMETER KeepHardwareUUIDs
        Übernimmt die Hardware-UUID der Quelle.
    .EXAMPLE
        Copy-VBoxVM 'Win11-Template' 'Win11-Test01' -Linked

        Linked Clone vom aktuellen Snapshot.
    .EXAMPLE
        New-VBoxSnapshot 'Ubuntu-Base' 'Basis'
        1..5 | ForEach-Object { Copy-VBoxVM 'Ubuntu-Base' "Node0$_" -Linked -Group 'Cluster' }

        Fünf Knoten auf einmal erzeugen.
    .EXAMPLE
        Copy-VBoxVM 'srv01' 'srv01-Kopie' -BaseFolder 'E:\VMs'

        Vollständiger Klon in einen anderen Ordner.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.VM
        Ein Objekt mit Name, UUID, State, OSType, MemoryMB, CPUs, VRAMMB, Firmware, Groups,
        Description, ConfigFile, Directory und StateChanged.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage clonevm <vm> --name <neu> --register
    .LINK
        New-VBoxSnapshot
    .LINK
        New-VBoxVM
    .LINK
        Remove-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('VBoxPS.VM')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory, Position = 1)]
        [string]$NewName,
        [switch]$Linked,
        [string]$SnapshotName,
        [ValidateSet('Machine', 'MachineAndChildren', 'All')]
        [string]$Mode = 'Machine',
        [string]$BaseFolder,
        [string[]]$Group,
        [switch]$KeepMacAddresses,
        [switch]$KeepDiskNames,
        [switch]$KeepHardwareUUIDs
    )
    process {
        if (-not $PSCmdlet.ShouldProcess($Name, "Klonen nach '$NewName'")) { return }

        if ($Linked -and -not $SnapshotName) {
            $cur = Get-VBoxSnapshot -Name $Name | Where-Object IsCurrent | Select-Object -First 1
            if (-not $cur) {
                throw "Ein Linked Clone benötigt einen Snapshot. '$Name' hat keinen – erst New-VBoxSnapshot ausführen oder -SnapshotName angeben."
            }
            $SnapshotName = $cur.SnapshotUUID
        }

        $cli = @('clonevm', $Name, '--name', $NewName, '--register', '--mode', $Mode.ToLowerInvariant())
        if ($SnapshotName) { $cli += '--snapshot', $SnapshotName }
        if ($BaseFolder)   { $cli += '--basefolder', (Resolve-VBoxHostPath $BaseFolder) }
        if ($Group)        { $cli += '--groups', (ConvertTo-VBoxGroupString $Group) }

        $opts = @()
        if ($Linked)            { $opts += 'Link' }
        if ($KeepMacAddresses)  { $opts += 'KeepAllMACs' }
        if ($KeepDiskNames)     { $opts += 'KeepDiskNames' }
        if ($KeepHardwareUUIDs) { $opts += 'KeepHwUUIDs' }
        if ($opts) { $cli += '--options', ($opts -join ',') }

        $null = Invoke-VBoxManageCore -ArgumentList $cli
        Get-VBoxVM -Name $NewName
    }
}

function Remove-VBoxVM {
    <#
    .SYNOPSIS
        Entfernt eine VM samt Festplatten und Dateien.
    .DESCRIPTION
        Das Cmdlet Remove-VBoxVM entfernt eine VM samt Festplatten und aller Dateien im VM-Ordner.
        Weil das nicht rückgängig zu machen ist, fragt das Cmdlet standardmäßig nach einer
        Bestätigung.

        Mit -KeepFiles wird die VM nur deregistriert, die Dateien bleiben erhalten.
    .PARAMETER Name
        Gibt die Namen oder UUIDs einer oder mehrerer VMs an. Sie können auch Objekte von Get-VBoxVM
        über die Pipeline übergeben.
    .PARAMETER KeepFiles
        Deregistriert die VM nur, ohne Dateien zu löschen.
    .PARAMETER Force
        Schaltet eine laufende VM vorher hart aus.
    .EXAMPLE
        Remove-VBoxVM 'Win11-Test01' -Force -Confirm:$false

        VM ohne Rückfrage löschen.
    .EXAMPLE
        Get-VBoxVM 'Node*' | Remove-VBoxVM -Force

        Alle Knoten entfernen.
    .EXAMPLE
        Remove-VBoxVM 'Archiv01' -KeepFiles

        Nur deregistrieren.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage unregistervm <vm> --delete
    .LINK
        New-VBoxVM
    .LINK
        Copy-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string[]]$Name,
        [switch]$KeepFiles,
        [switch]$Force
    )
    process {
        foreach ($vm in $Name) {
            $what = if ($KeepFiles) { 'VM deregistrieren (Dateien bleiben erhalten)' } else { 'VM inkl. Festplatten und Dateien löschen' }
            if (-not $PSCmdlet.ShouldProcess($vm, $what)) { continue }

            if (Test-VBoxVMOnline -Name $vm) {
                if (-not $Force) { throw "VM '$vm' läuft. Erst stoppen oder -Force verwenden." }
                $null = Invoke-VBoxManageCore -ArgumentList 'controlvm', $vm, 'poweroff'
                $null = Wait-VBoxVM -Name $vm -State 'poweroff', 'aborted' -TimeoutSec 60 -PollIntervalSec 1
            }
            $cli = @('unregistervm', $vm)
            if (-not $KeepFiles) { $cli += '--delete' }
            $null = Invoke-VBoxManageWithRetry -ArgumentList $cli
        }
    }
}

function Set-VBoxVM {
    <#
    .SYNOPSIS
        Ändert Hardware- und Grundeinstellungen einer ausgeschalteten VM.
    .DESCRIPTION
        Das Cmdlet Set-VBoxVM ändert Hardware- und Grundeinstellungen einer VM. Es werden nur die
        angegebenen Einstellungen geändert.

        Die VM muss ausgeschaltet sein. Netzwerkadapter konfigurieren Sie mit Set-
        VBoxVMNetworkAdapter, Laufwerke mit den Storage-Cmdlets.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER NewName
        Benennt die VM um.
    .PARAMETER OSType
        Ändert den OS-Typ.
    .PARAMETER MemoryMB
        Gibt den Arbeitsspeicher in MB an.
    .PARAMETER CPUs
        Gibt die Anzahl der virtuellen CPUs an.
    .PARAMETER CpuExecutionCap
        Begrenzt die CPU-Nutzung pro virtueller CPU in Prozent (1–100).
    .PARAMETER VRAMMB
        Gibt den Grafikspeicher in MB an.
    .PARAMETER Firmware
        Gibt die Firmware an: BIOS oder EFI.
    .PARAMETER GraphicsController
        Gibt den Grafikcontroller an.
    .PARAMETER BootOrder
        Gibt bis zu vier Bootgeräte in Reihenfolge an: None, Floppy, DVD, Disk, Net. Nicht angegebene
        Plätze werden auf None gesetzt.
    .PARAMETER Clipboard
        Gibt die gemeinsame Zwischenablage an: Disabled, HostToGuest, GuestToHost oder Bidirectional.
    .PARAMETER DragAndDrop
        Gibt Drag & Drop zwischen Host und Gast an: Disabled, HostToGuest, GuestToHost oder
        Bidirectional.
    .PARAMETER NestedVirtualization
        Aktiviert ($true) oder deaktiviert ($false) verschachtelte Virtualisierung.
    .PARAMETER IoApic
        Aktiviert oder deaktiviert den I/O-APIC.
    .PARAMETER Pae
        Aktiviert oder deaktiviert PAE/NX.
    .PARAMETER Description
        Gibt eine Beschreibung für die VM an.
    .PARAMETER AdditionalArgument
        Gibt weitere modifyvm-Optionen an, die unverändert angehängt werden, z. B. '--usbxhci','on'.
    .PARAMETER PassThru
        Gibt nach der Aktion ein VBoxPS.VM-Objekt mit dem aktuellen Zustand der VM zurück.
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .EXAMPLE
        Set-VBoxVM 'Win11-Lab' -MemoryMB 16384 -CPUs 8 -Clipboard Bidirectional -DragAndDrop Bidirectional

        Ressourcen erhöhen und Zwischenablage aktivieren.
    .EXAMPLE
        Set-VBoxVM 'srv01' -BootOrder Net, Disk

        PXE-Boot zuerst.
    .EXAMPLE
        Set-VBoxVM 'srv01' -AdditionalArgument '--usbxhci', 'on'

        Option ohne eigenen Parameter setzen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .OUTPUTS
        VBoxPS.VM
        Wenn Sie -PassThru angeben, gibt das Cmdlet die VM mit ihrem aktuellen Zustand zurück.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage modifyvm <vm> ...
    .LINK
        Get-VBoxVM
    .LINK
        Set-VBoxVMNetworkAdapter
    .LINK
        New-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [string]$NewName,
        [string]$OSType,
        [ValidateRange(4, 2097152)][int]$MemoryMB,
        [ValidateRange(1, 64)][int]$CPUs,
        [ValidateRange(1, 100)][int]$CpuExecutionCap,
        [ValidateRange(0, 256)][int]$VRAMMB,
        [ValidateSet('BIOS', 'EFI')][string]$Firmware,
        [ValidateSet('VMSVGA', 'VBoxSVGA', 'VBoxVGA', 'None')][string]$GraphicsController,
        [ValidateSet('None', 'Floppy', 'DVD', 'Disk', 'Net')][string[]]$BootOrder,
        [ValidateSet('Disabled', 'HostToGuest', 'GuestToHost', 'Bidirectional')][string]$Clipboard,
        [ValidateSet('Disabled', 'HostToGuest', 'GuestToHost', 'Bidirectional')][string]$DragAndDrop,
        [bool]$NestedVirtualization,
        [bool]$IoApic,
        [bool]$Pae,
        [string]$Description,
        [string[]]$AdditionalArgument,
        [switch]$PassThru
    )
    process {
        $p   = $PSBoundParameters
        $cli = @('modifyvm', $Name)
        if ($p.ContainsKey('NewName'))            { $cli += '--name', $NewName }
        if ($p.ContainsKey('OSType'))             { $cli += '--ostype', $OSType }
        if ($p.ContainsKey('MemoryMB'))           { $cli += '--memory', $MemoryMB }
        if ($p.ContainsKey('CPUs'))               { $cli += '--cpus', $CPUs }
        if ($p.ContainsKey('CpuExecutionCap'))    { $cli += '--cpuexecutioncap', $CpuExecutionCap }
        if ($p.ContainsKey('VRAMMB'))             { $cli += '--vram', $VRAMMB }
        if ($p.ContainsKey('Firmware'))           { $cli += '--firmware', $Firmware.ToLowerInvariant() }
        if ($p.ContainsKey('GraphicsController')) { $cli += '--graphicscontroller', $GraphicsController.ToLowerInvariant() }
        if ($p.ContainsKey('Clipboard'))          { $cli += '--clipboard-mode', $Clipboard.ToLowerInvariant() }
        if ($p.ContainsKey('DragAndDrop'))        { $cli += '--draganddrop', $DragAndDrop.ToLowerInvariant() }
        if ($p.ContainsKey('NestedVirtualization')) { $cli += '--nested-hw-virt', (ConvertTo-VBoxOnOff $NestedVirtualization) }
        if ($p.ContainsKey('IoApic'))             { $cli += '--ioapic', (ConvertTo-VBoxOnOff $IoApic) }
        if ($p.ContainsKey('Pae'))                { $cli += '--pae', (ConvertTo-VBoxOnOff $Pae) }
        if ($p.ContainsKey('Description'))        { $cli += '--description', $Description }
        if ($p.ContainsKey('BootOrder')) {
            if ($BootOrder.Count -gt 4) { throw '-BootOrder: maximal 4 Einträge.' }
            for ($i = 0; $i -lt 4; $i++) {
                $dev = if ($i -lt $BootOrder.Count) { $BootOrder[$i].ToLowerInvariant() } else { 'none' }
                $cli += "--boot$($i + 1)", $dev
            }
        }
        if ($AdditionalArgument) { $cli += $AdditionalArgument }

        if ($cli.Count -le 2) { Write-Warning 'Keine Änderungen angegeben.'; return }
        if (Test-VBoxVMOnline -Name $Name) { throw "VM '$Name' muss für Set-VBoxVM ausgeschaltet sein." }

        if ($PSCmdlet.ShouldProcess($Name, 'VM-Einstellungen ändern')) {
            $null = Invoke-VBoxManageCore -ArgumentList $cli
            if ($PassThru) { Get-VBoxVM -Name $(if ($NewName) { $NewName } else { $Name }) }
        }
    }
}

function Import-VBoxAppliance {
    <#
    .SYNOPSIS
        Importiert eine OVA/OVF-Appliance.
    .DESCRIPTION
        Das Cmdlet Import-VBoxAppliance importiert eine OVA- oder OVF-Appliance und gibt die neu
        registrierten VMs zurück.

        -VMName und -BaseFolder beziehen sich auf das erste virtuelle System in der Appliance.
    .PARAMETER Path
        Gibt den Pfad zur OVA- oder OVF-Datei an.
    .PARAMETER VMName
        Gibt den Namen der importierten VM an.
    .PARAMETER BaseFolder
        Gibt den Ordner an, in dem die VM angelegt wird.
    .PARAMETER KeepMacAddresses
        Übernimmt die MAC-Adressen aus der Appliance.
    .EXAMPLE
        Import-VBoxAppliance 'D:\Export\Win11-Template.ova' -VMName 'Win11-Template' -BaseFolder 'E:\VMs'

        Vorlage importieren.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        VBoxPS.VM
        Ein Objekt mit Name, UUID, State, OSType, MemoryMB, CPUs, VRAMMB, Firmware, Groups,
        Description, ConfigFile, Directory und StateChanged.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage import <datei>
    .LINK
        Export-VBoxAppliance
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('VBoxPS.VM')]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Path,
        [string]$VMName,
        [string]$BaseFolder,
        [switch]$KeepMacAddresses
    )
    $Path = Resolve-VBoxHostPath $Path
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Datei nicht gefunden: $Path" }
    if (-not $PSCmdlet.ShouldProcess($Path, 'Appliance importieren')) { return }

    $before = @(Get-VBoxVMList | ForEach-Object UUID)
    $cli = @('import', $Path)
    if ($VMName -or $BaseFolder) { $cli += '--vsys', '0' }
    if ($VMName)     { $cli += '--vmname', $VMName }
    if ($BaseFolder) { $cli += '--basefolder', (Resolve-VBoxHostPath $BaseFolder) }
    if ($KeepMacAddresses) { $cli += '--options', 'keepallmacs' }
    $null = Invoke-VBoxManageCore -ArgumentList $cli

    Get-VBoxVMList | Where-Object { $before -notcontains $_.UUID } | ForEach-Object { Get-VBoxVM -Name $_.UUID }
}

function Export-VBoxAppliance {
    <#
    .SYNOPSIS
        Exportiert eine oder mehrere VMs als OVA/OVF.
    .DESCRIPTION
        Das Cmdlet Export-VBoxAppliance exportiert eine oder mehrere VMs als OVA (eine Datei) oder OVF
        (mehrere Dateien). Das Format ergibt sich aus der Dateiendung von -Path.

        Werden mehrere VMs über die Pipeline übergeben, landen alle in derselben Appliance.
    .PARAMETER Name
        Gibt die Namen oder UUIDs einer oder mehrerer VMs an. Sie können auch Objekte von Get-VBoxVM
        über die Pipeline übergeben.
    .PARAMETER Path
        Gibt die Zieldatei an, z. B. Vorlage.ova oder Vorlage.ovf.
    .PARAMETER OvfVersion
        Gibt die OVF-Version an: OVF10 oder OVF20.
    .PARAMETER Manifest
        Erstellt eine Manifestdatei mit Prüfsummen.
    .PARAMETER IncludeIso
        Nimmt eingelegte ISO-Dateien mit in die Appliance auf.
    .PARAMETER StripMacAddresses
        Exportiert keine MAC-Adressen. Beim Import werden neue erzeugt.
    .EXAMPLE
        Export-VBoxAppliance 'Win11-Template' -Path 'D:\Export\Win11-Template.ova' -Manifest

        Vorlage als OVA exportieren.
    .EXAMPLE
        Get-VBoxVM 'Lab-*' | Export-VBoxAppliance -Path 'D:\Export\Lab.ova' -StripMacAddresses

        Ganzes Lab in eine Appliance.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        System.IO.FileInfo
        Die erstellte Appliance-Datei.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage export <vm...> --output <datei>
    .LINK
        Import-VBoxAppliance
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string[]]$Name,
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('OVF10', 'OVF20')][string]$OvfVersion = 'OVF20',
        [switch]$Manifest,
        [switch]$IncludeIso,
        [switch]$StripMacAddresses
    )
    begin { $all = New-Object System.Collections.Generic.List[string] }
    process { foreach ($n in $Name) { $all.Add($n) } }
    end {
        $target = Resolve-VBoxHostPath $Path
        if (-not $PSCmdlet.ShouldProcess(($all -join ', '), "Exportieren nach $target")) { return }
        $cli = @('export') + $all.ToArray() + @('--output', $target, "--$($OvfVersion.ToLowerInvariant())")
        $opts = @()
        if ($Manifest)          { $opts += 'manifest' }
        if ($IncludeIso)        { $opts += 'iso' }
        if ($StripMacAddresses) { $opts += 'nomacs' }
        if ($opts) { $cli += '--options', ($opts -join ',') }
        $null = Invoke-VBoxManageCore -ArgumentList $cli
        Get-Item -LiteralPath $target -ErrorAction SilentlyContinue
    }
}
