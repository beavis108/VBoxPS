function Start-VBoxVM {
    <#
    .SYNOPSIS
        Startet eine oder mehrere VMs.
    .DESCRIPTION
        Das Cmdlet Start-VBoxVM startet eine oder mehrere VMs. Standardmäßig laufen sie headless, also
        ohne Fenster.

        Mit -WaitForGuestAdditions wartet das Cmdlet, bis die Guest Additions im Gast laufen. Danach
        können Sie sofort Gastbefehle ausführen.
    .PARAMETER Name
        Gibt die Namen oder UUIDs einer oder mehrerer VMs an. Sie können auch Objekte von Get-VBoxVM
        über die Pipeline übergeben.
    .PARAMETER Type
        Gibt an, wie die VM gestartet wird: Headless (ohne Fenster), GUI (normales Fenster) oder
        Separate (Fenster kann geschlossen werden, die VM läuft weiter).
    .PARAMETER WaitForGuestAdditions
        Wartet nach dem Start, bis die Guest Additions den Run-Level Userland erreicht haben.
    .PARAMETER TimeoutSec
        Gibt an, wie lange bei -WaitForGuestAdditions maximal gewartet wird.
    .PARAMETER PassThru
        Gibt nach der Aktion ein VBoxPS.VM-Objekt mit dem aktuellen Zustand der VM zurück.
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .EXAMPLE
        Start-VBoxVM 'Win11-Lab'

        VM headless starten.
    .EXAMPLE
        Start-VBoxVM 'Win11-Lab' -WaitForGuestAdditions -TimeoutSec 900
        Invoke-VBoxGuestCommand 'Win11-Lab' -Credential $cred -FilePath 'C:\Windows\System32\hostname.exe'

        Starten und auf den Gast warten.
    .EXAMPLE
        Get-VBoxVM 'Lab-*' | Start-VBoxVM -Type GUI

        Mehrere VMs mit Fenster starten.
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
        Zugrunde liegender Aufruf: VBoxManage startvm <vm> --type <typ>
    .LINK
        Stop-VBoxVM
    .LINK
        Wait-VBoxGuestAdditions
    .LINK
        Restart-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string[]]$Name,
        [ValidateSet('Headless', 'GUI', 'Separate')]
        [string]$Type = 'Headless',
        [switch]$WaitForGuestAdditions,
        [int]$TimeoutSec = 600,
        [switch]$PassThru
    )
    process {
        foreach ($vm in $Name) {
            if (-not $PSCmdlet.ShouldProcess($vm, "VM starten ($Type)")) { continue }
            $null = Invoke-VBoxManageCore -ArgumentList 'startvm', $vm, '--type', $Type.ToLowerInvariant()
            if ($WaitForGuestAdditions) { $null = Wait-VBoxGuestAdditions -Name $vm -TimeoutSec $TimeoutSec }
            if ($PassThru) { Get-VBoxVM -Name $vm }
        }
    }
}

function Stop-VBoxVM {
    <#
    .SYNOPSIS
        Fährt eine VM herunter, schaltet sie aus oder sichert ihren Zustand.
    .DESCRIPTION
        Das Cmdlet Stop-VBoxVM fährt eine VM herunter, schaltet sie aus oder sichert ihren Zustand.

        AcpiPowerButton und Shutdown lösen nur das Herunterfahren aus und kehren sofort zurück. Mit
        -Wait wartet das Cmdlet, bis die VM aus ist. Mit -Force schaltet es die VM nach Ablauf von
        -TimeoutSec zusätzlich hart aus.

        VMs, die bereits aus sind, werden übersprungen.
    .PARAMETER Name
        Gibt die Namen oder UUIDs einer oder mehrerer VMs an. Sie können auch Objekte von Get-VBoxVM
        über die Pipeline übergeben.
    .PARAMETER Mode
        Gibt an, wie die VM gestoppt wird:
        - AcpiPowerButton (Standard): drückt den virtuellen Ein/Aus-Schalter, der Gast fährt sauber
          herunter.
        - Shutdown: fährt über die Guest Additions herunter (ab VirtualBox 7.0).
        - PowerOff: schaltet sofort aus, nicht gespeicherte Daten im Gast gehen verloren.
        - SaveState: sichert den Arbeitsspeicher auf Platte, die VM setzt beim nächsten Start dort
          fort.
    .PARAMETER Wait
        Wartet bei AcpiPowerButton und Shutdown, bis die VM ausgeschaltet ist.
    .PARAMETER Force
        Wie -Wait, schaltet die VM aber hart aus, wenn sie nach -TimeoutSec noch läuft.
    .PARAMETER TimeoutSec
        Gibt an, wie lange bei -Wait oder -Force auf das Herunterfahren gewartet wird.
    .PARAMETER PassThru
        Gibt nach der Aktion ein VBoxPS.VM-Objekt mit dem aktuellen Zustand der VM zurück.
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .EXAMPLE
        Stop-VBoxVM 'Win11-Lab' -Wait

        VM sauber herunterfahren und warten.
    .EXAMPLE
        Get-VBoxVM -Running | Stop-VBoxVM -Force -TimeoutSec 120

        Alle VMs stoppen, notfalls hart.
        Hängt ein Gast beim Herunterfahren, wird er nach zwei Minuten ausgeschaltet.
    .EXAMPLE
        Stop-VBoxVM 'srv01' -Mode SaveState

        Zustand sichern.
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
        Zugrunde liegender Aufruf: VBoxManage controlvm <vm> acpipowerbutton | shutdown | poweroff |
        savestate
    .LINK
        Start-VBoxVM
    .LINK
        Wait-VBoxVM
    .LINK
        Suspend-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string[]]$Name,
        [ValidateSet('AcpiPowerButton', 'Shutdown', 'PowerOff', 'SaveState')]
        [string]$Mode = 'AcpiPowerButton',
        [switch]$Wait,
        [switch]$Force,
        [int]$TimeoutSec = 300,
        [switch]$PassThru
    )
    process {
        foreach ($vm in $Name) {
            if (-not (Test-VBoxVMOnline -Name $vm)) {
                Write-Verbose "VM '$vm' läuft nicht."
                if ($PassThru) { Get-VBoxVM -Name $vm }
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($vm, "VM stoppen ($Mode)")) { continue }

            switch ($Mode) {
                'AcpiPowerButton' { $action = 'acpipowerbutton' }
                'Shutdown'        { Assert-VBoxVersion -Minimum '7.0' -Feature 'Stop-VBoxVM -Mode Shutdown'; $action = 'shutdown' }
                'PowerOff'        { $action = 'poweroff' }
                'SaveState'       { $action = 'savestate' }
            }
            $null = Invoke-VBoxManageCore -ArgumentList 'controlvm', $vm, $action

            if (($Wait -or $Force) -and $Mode -in 'AcpiPowerButton', 'Shutdown') {
                try {
                    $null = Wait-VBoxVM -Name $vm -State 'poweroff', 'aborted' -TimeoutSec $TimeoutSec
                }
                catch {
                    if (-not $Force) { throw }
                    Write-Warning "VM '$vm' hat nach $TimeoutSec s nicht reagiert – schalte hart aus."
                    $null = Invoke-VBoxManageCore -ArgumentList 'controlvm', $vm, 'poweroff'
                }
            }
            if ($PassThru) { Get-VBoxVM -Name $vm }
        }
    }
}

function Suspend-VBoxVM {
    <#
    .SYNOPSIS
        Pausiert eine laufende VM.
    .DESCRIPTION
        Das Cmdlet Suspend-VBoxVM pausiert eine laufende VM. Der Zustand bleibt im Arbeitsspeicher des
        Hosts. Mit Resume-VBoxVM setzen Sie die VM fort.
    .PARAMETER Name
        Gibt die Namen oder UUIDs einer oder mehrerer VMs an. Sie können auch Objekte von Get-VBoxVM
        über die Pipeline übergeben.
    .PARAMETER PassThru
        Gibt nach der Aktion ein VBoxPS.VM-Objekt mit dem aktuellen Zustand der VM zurück.
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .EXAMPLE
        Suspend-VBoxVM 'Win11-Lab'

        VM pausieren.
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
        Zugrunde liegender Aufruf: VBoxManage controlvm <vm> pause
    .LINK
        Resume-VBoxVM
    .LINK
        Stop-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string[]]$Name,
        [switch]$PassThru
    )
    process {
        foreach ($vm in $Name) {
            if ($PSCmdlet.ShouldProcess($vm, 'VM pausieren')) {
                $null = Invoke-VBoxManageCore -ArgumentList 'controlvm', $vm, 'pause'
                if ($PassThru) { Get-VBoxVM -Name $vm }
            }
        }
    }
}

function Resume-VBoxVM {
    <#
    .SYNOPSIS
        Setzt eine pausierte VM fort.
    .DESCRIPTION
        Das Cmdlet Resume-VBoxVM setzt eine mit Suspend-VBoxVM pausierte VM fort.
    .PARAMETER Name
        Gibt die Namen oder UUIDs einer oder mehrerer VMs an. Sie können auch Objekte von Get-VBoxVM
        über die Pipeline übergeben.
    .PARAMETER PassThru
        Gibt nach der Aktion ein VBoxPS.VM-Objekt mit dem aktuellen Zustand der VM zurück.
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .EXAMPLE
        Get-VBoxVM | Where-Object State -eq 'paused' | Resume-VBoxVM

        Alle pausierten VMs fortsetzen.
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
        Zugrunde liegender Aufruf: VBoxManage controlvm <vm> resume
    .LINK
        Suspend-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string[]]$Name,
        [switch]$PassThru
    )
    process {
        foreach ($vm in $Name) {
            if ($PSCmdlet.ShouldProcess($vm, 'VM fortsetzen')) {
                $null = Invoke-VBoxManageCore -ArgumentList 'controlvm', $vm, 'resume'
                if ($PassThru) { Get-VBoxVM -Name $vm }
            }
        }
    }
}

function Restart-VBoxVM {
    <#
    .SYNOPSIS
        Startet eine VM neu.
    .DESCRIPTION
        Das Cmdlet Restart-VBoxVM startet eine laufende VM neu.

        Reset entspricht einem harten Neustart über den Reset-Knopf. Reboot startet den Gast über die
        Guest Additions sauber neu und erfordert VirtualBox 7.0.
    .PARAMETER Name
        Gibt die Namen oder UUIDs einer oder mehrerer VMs an. Sie können auch Objekte von Get-VBoxVM
        über die Pipeline übergeben.
    .PARAMETER Mode
        Gibt die Art des Neustarts an: Reset (Standard, hart) oder Reboot (sauber über die Guest
        Additions, ab VirtualBox 7.0).
    .PARAMETER PassThru
        Gibt nach der Aktion ein VBoxPS.VM-Objekt mit dem aktuellen Zustand der VM zurück.
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .EXAMPLE
        Restart-VBoxVM 'Win11-Lab' -Mode Reboot

        Gast sauber neu starten.
    .EXAMPLE
        Restart-VBoxVM 'srv01'

        Hängende VM zurücksetzen.
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
        Zugrunde liegender Aufruf: VBoxManage controlvm <vm> reset | reboot
    .LINK
        Start-VBoxVM
    .LINK
        Stop-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string[]]$Name,
        [ValidateSet('Reset', 'Reboot')]
        [string]$Mode = 'Reset',
        [switch]$PassThru
    )
    process {
        foreach ($vm in $Name) {
            if (-not $PSCmdlet.ShouldProcess($vm, "VM neu starten ($Mode)")) { continue }
            if ($Mode -eq 'Reboot') { Assert-VBoxVersion -Minimum '7.0' -Feature 'Restart-VBoxVM -Mode Reboot' }
            $null = Invoke-VBoxManageCore -ArgumentList 'controlvm', $vm, $Mode.ToLowerInvariant()
            if ($PassThru) { Get-VBoxVM -Name $vm }
        }
    }
}

function Wait-VBoxVM {
    <#
    .SYNOPSIS
        Wartet, bis eine VM einen bestimmten Zustand erreicht.
    .DESCRIPTION
        Das Cmdlet Wait-VBoxVM wartet, bis eine VM einen der angegebenen Zustände erreicht, und gibt
        sie dann zurück. Wird der Zustand nicht rechtzeitig erreicht, löst es einen Fehler aus.

        Typischer Einsatz: nach einer unbeaufsichtigten Installation, die die VM am Ende selbst
        ausschaltet.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER State
        Gibt einen oder mehrere Zielzustände an, z. B. poweroff, running, paused, saved oder aborted.
        Standard ist poweroff.
    .PARAMETER TimeoutSec
        Gibt an, wie viele Sekunden das Cmdlet maximal wartet. Nach Ablauf wird ein Fehler ausgelöst.
    .PARAMETER PollIntervalSec
        Gibt an, in welchem Abstand (Sekunden) der Zustand abgefragt wird.
    .EXAMPLE
        Wait-VBoxVM 'Win11-Lab' -State poweroff -TimeoutSec 3600

        Auf das Ausschalten warten.
    .EXAMPLE
        Wait-VBoxVM 'srv01' -State poweroff, aborted

        Auf einen von mehreren Zuständen warten.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.VM
        Ein Objekt mit Name, UUID, State, OSType, MemoryMB, CPUs, VRAMMB, Firmware, Groups,
        Description, ConfigFile, Directory und StateChanged.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage showvminfo <vm> --machinereadable
    .LINK
        Stop-VBoxVM
    .LINK
        Wait-VBoxGuestAdditions
    #>
    [CmdletBinding()]
    [OutputType('VBoxPS.VM')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [string[]]$State = @('poweroff'),
        [int]$TimeoutSec = 300,
        [int]$PollIntervalSec = 2
    )
    process {
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        do {
            $info = Get-VBoxVMInfo -Name $Name
            if ($State -contains $info['VMState']) { return (ConvertTo-VBoxVMObject -Info $info) }
            Start-Sleep -Seconds $PollIntervalSec
        } while ((Get-Date) -lt $deadline)
        throw "Zeitüberschreitung: VM '$Name' hat den Zustand '$($State -join '/')' nicht innerhalb von $TimeoutSec s erreicht (aktuell: $($info['VMState']))."
    }
}

#region Snapshots

function Get-VBoxSnapshot {
    <#
    .SYNOPSIS
        Listet die Snapshots einer VM (inkl. Baumtiefe und aktuellem Snapshot).
    .DESCRIPTION
        Das Cmdlet Get-VBoxSnapshot gibt die Snapshots einer VM zurück, einschließlich Baumtiefe,
        übergeordnetem Snapshot und der Information, welcher Snapshot aktuell ist.

        Hat die VM keine Snapshots, gibt das Cmdlet nichts zurück.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER SnapshotName
        Filtert nach Snapshot-Namen. Platzhalter sind zulässig.
    .EXAMPLE
        Get-VBoxSnapshot 'Win11-Lab'

        Snapshot-Baum anzeigen.
        VMName    SnapshotName Depth IsCurrent Description
        ------    ------------ ----- --------- -----------
        Win11-Lab Basis            0     False Frisch installiert
        Win11-Lab Updates          1      True
    .EXAMPLE
        Get-VBoxSnapshot 'Win11-Lab' | ForEach-Object { ('  ' * $_.Depth) + $_.SnapshotName }

        Eingerückt darstellen.
    .EXAMPLE
        Get-VBoxSnapshot 'Win11-Lab' 'Test*' | Remove-VBoxSnapshot

        Snapshots nach Namen löschen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.Snapshot
        Objekt mit VMName, SnapshotName, SnapshotUUID, Description, Depth, ParentName und IsCurrent.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage snapshot <vm> list --machinereadable
    .LINK
        New-VBoxSnapshot
    .LINK
        Restore-VBoxSnapshot
    .LINK
        Remove-VBoxSnapshot
    #>
    [CmdletBinding()]
    [OutputType('VBoxPS.Snapshot')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Position = 1)]
        [SupportsWildcards()]
        [string]$SnapshotName = '*'
    )
    process {
        $r = Invoke-VBoxManageCore -ArgumentList 'snapshot', $Name, 'list', '--machinereadable' -NoThrow
        if ($r.ExitCode -ne 0) {
            if ("$($r.StdOut)$($r.StdErr)" -match 'does not have any snapshots') { return }
            throw (Format-VBoxErrorMessage -ArgumentList 'snapshot', $Name, 'list' -Result $r)
        }
        $info        = ConvertFrom-VBoxMachineReadable -Line $r.Lines
        $currentUuid = $info['CurrentSnapshotUUID']

        foreach ($key in @($info.Keys)) {
            if ($key -notmatch '^SnapshotName(?<sfx>(-\d+)*)$') { continue }
            $sfx    = $Matches['sfx']
            $parent = $null
            if ($sfx) { $parent = $info['SnapshotName' + ($sfx -replace '-\d+$', '')] }
            $uuid = $info["SnapshotUUID$sfx"]
            $obj = [pscustomobject]@{
                PSTypeName   = 'VBoxPS.Snapshot'
                VMName       = $Name
                SnapshotName = $info[$key]
                SnapshotUUID = $uuid
                Description  = $info["SnapshotDescription$sfx"]
                Depth        = ([regex]::Matches($sfx, '-')).Count
                ParentName   = $parent
                IsCurrent    = ($uuid -and $uuid -eq $currentUuid)
            }
            if ($obj.SnapshotName -like $SnapshotName -or $obj.SnapshotName -eq $SnapshotName) { $obj }
        }
    }
}

function New-VBoxSnapshot {
    <#
    .SYNOPSIS
        Erstellt einen Snapshot.
    .DESCRIPTION
        Das Cmdlet New-VBoxSnapshot erstellt einen Snapshot einer VM und gibt ihn zurück.

        Bei laufenden VMs wird die VM für den Snapshot kurz angehalten, sofern Sie nicht -Live
        angeben.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER SnapshotName
        Gibt den Namen des Snapshots an. Standard ist Snapshot <Datum Uhrzeit>.
    .PARAMETER Description
        Gibt eine Beschreibung für den Snapshot an.
    .PARAMETER Live
        Erstellt den Snapshot einer laufenden VM, ohne sie anzuhalten.
    .EXAMPLE
        New-VBoxSnapshot 'Win11-Lab' 'Vor Update' -Description 'Stand vor dem Patchday'

        Snapshot vor einem Update.
    .EXAMPLE
        Get-VBoxVM 'Lab-*' | New-VBoxSnapshot -SnapshotName 'Basis'

        Snapshot aller Lab-VMs.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.Snapshot
        Der neu erstellte Snapshot.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage snapshot <vm> take <name>
    .LINK
        Get-VBoxSnapshot
    .LINK
        Restore-VBoxSnapshot
    .LINK
        Copy-VBoxVM
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('VBoxPS.Snapshot')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Position = 1)]
        [string]$SnapshotName = ('Snapshot {0:yyyy-MM-dd HH-mm-ss}' -f (Get-Date)),
        [string]$Description,
        [switch]$Live
    )
    process {
        if (-not $PSCmdlet.ShouldProcess($Name, "Snapshot '$SnapshotName' erstellen")) { return }
        $cli = @('snapshot', $Name, 'take', $SnapshotName)
        if ($Description) { $cli += '--description', $Description }
        if ($Live) { $cli += '--live' }
        $r = Invoke-VBoxManageCore -ArgumentList $cli

        $uuid = $null
        if ($r.StdOut -match 'UUID:\s*(?<u>[0-9a-fA-F-]{36})') { $uuid = $Matches['u'] }
        $snaps = @(Get-VBoxSnapshot -Name $Name)
        $hit = $snaps | Where-Object { $uuid -and $_.SnapshotUUID -eq $uuid } | Select-Object -First 1
        if (-not $hit) { $hit = $snaps | Where-Object { $_.SnapshotName -eq $SnapshotName } | Select-Object -Last 1 }
        $hit
    }
}

function Restore-VBoxSnapshot {
    <#
    .SYNOPSIS
        Setzt eine VM auf einen Snapshot zurück.
    .DESCRIPTION
        Das Cmdlet Restore-VBoxSnapshot setzt eine VM auf einen Snapshot zurück. Alle Änderungen seit
        dem Snapshot gehen verloren, deshalb fragt das Cmdlet standardmäßig nach einer Bestätigung.

        Die VM muss ausgeschaltet sein. Mit -Force wird eine laufende VM vorher hart ausgeschaltet.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER SnapshotName
        Gibt den Namen oder die UUID des Snapshots an, auf den zurückgesetzt wird.
    .PARAMETER Current
        Setzt auf den aktuellen Snapshot zurück.
    .PARAMETER Force
        Schaltet eine laufende VM vor dem Zurücksetzen hart aus.
    .PARAMETER PassThru
        Gibt nach der Aktion ein VBoxPS.VM-Objekt mit dem aktuellen Zustand der VM zurück.
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .EXAMPLE
        Restore-VBoxSnapshot 'Win11-Lab' 'Vor Update' -Force

        Auf einen benannten Snapshot zurücksetzen.
    .EXAMPLE
        Get-VBoxVM 'Lab-*' | ForEach-Object {
            Restore-VBoxSnapshot $_.Name -Current -Force -Confirm:$false
            Start-VBoxVM $_.Name
        }

        Lab ohne Rückfrage zurücksetzen und starten.
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
        Zugrunde liegender Aufruf: VBoxManage snapshot <vm> restore <name> | restorecurrent
    .LINK
        Get-VBoxSnapshot
    .LINK
        New-VBoxSnapshot
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName)]
        [string]$SnapshotName,
        [Parameter(Mandatory, ParameterSetName = 'Current')]
        [switch]$Current,
        [switch]$Force,
        [switch]$PassThru
    )
    process {
        $target = if ($Current) { 'aktuellen Snapshot' } else { "Snapshot '$SnapshotName'" }
        if (-not $PSCmdlet.ShouldProcess($Name, "Auf $target zurücksetzen")) { return }

        if (Test-VBoxVMOnline -Name $Name) {
            if (-not $Force) { throw "VM '$Name' läuft. Zum Zurücksetzen ausschalten oder -Force verwenden." }
            $null = Invoke-VBoxManageCore -ArgumentList 'controlvm', $Name, 'poweroff'
            $null = Wait-VBoxVM -Name $Name -State 'poweroff', 'aborted' -TimeoutSec 60 -PollIntervalSec 1
        }
        $cli = if ($Current) { @('snapshot', $Name, 'restorecurrent') } else { @('snapshot', $Name, 'restore', $SnapshotName) }
        $null = Invoke-VBoxManageWithRetry -ArgumentList $cli
        if ($PassThru) { Get-VBoxVM -Name $Name }
    }
}

function Remove-VBoxSnapshot {
    <#
    .SYNOPSIS
        Löscht einen Snapshot (die Differenzdaten werden zusammengeführt).
    .DESCRIPTION
        Das Cmdlet Remove-VBoxSnapshot löscht einen Snapshot. Die Differenzdaten werden dabei
        zusammengeführt, das kann bei großen Platten dauern.

        Wird ein Objekt von Get-VBoxSnapshot übergeben, verwendet das Cmdlet die UUID. So wird auch
        bei doppelten Namen der richtige Snapshot gelöscht.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER SnapshotName
        Gibt den Namen des zu löschenden Snapshots an.
    .PARAMETER SnapshotUUID
        Gibt die UUID des Snapshots an. Hat Vorrang vor -SnapshotName, wird normalerweise über die
        Pipeline gebunden.
    .EXAMPLE
        Remove-VBoxSnapshot 'Win11-Lab' 'Vor Update'

        Snapshot löschen.
    .EXAMPLE
        Get-VBoxSnapshot 'Win11-Lab' | Sort-Object Depth -Descending | Remove-VBoxSnapshot -Confirm:$false

        Alle Snapshots ohne Rückfrage löschen.
        Durch die Sortierung werden tiefere Snapshots zuerst entfernt.
    .INPUTS
        VBoxPS.Snapshot
        Sie können Snapshot-Objekte von Get-VBoxSnapshot übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage snapshot <vm> delete <name>
    .LINK
        Get-VBoxSnapshot
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [string]$SnapshotName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$SnapshotUUID
    )
    process {
        $id = if ($SnapshotUUID) { $SnapshotUUID } else { $SnapshotName }
        if ($PSCmdlet.ShouldProcess($Name, "Snapshot '$SnapshotName' löschen")) {
            $null = Invoke-VBoxManageCore -ArgumentList 'snapshot', $Name, 'delete', $id
        }
    }
}

#endregion
