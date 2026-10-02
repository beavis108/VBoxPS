#region Unattended Install

function Get-VBoxUnattendedIsoInfo {
    <#
    .SYNOPSIS
        Analysiert ein Installations-ISO (erkanntes OS, Sprache, ob Unattended unterstützt wird).
    .DESCRIPTION
        Das Cmdlet Get-VBoxUnattendedIsoInfo analysiert ein Installations-ISO. Es zeigt das erkannte
        Betriebssystem, Version, Sprachen und ob VirtualBox dafür eine unbeaufsichtigte Installation
        unterstützt.
    .PARAMETER IsoPath
        Gibt den Pfad zur ISO-Datei an.
    .EXAMPLE
        Get-VBoxUnattendedIsoInfo 'D:\ISO\Win11_24H2.iso'

        ISO prüfen.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Objekt mit den Werten aus unattended detect (u. a. OSTypeId, OSVersion, OSLanguages,
        IsInstallSupported).
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage unattended detect --iso <iso> --machine-readable
    .LINK
        Start-VBoxUnattendedInstall
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$IsoPath)
    $IsoPath = Resolve-VBoxHostPath $IsoPath
    if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) { throw "ISO nicht gefunden: $IsoPath" }
    $r = Invoke-VBoxManageCore -ArgumentList 'unattended', 'detect', '--iso', $IsoPath, '--machine-readable'
    [pscustomobject](ConvertFrom-VBoxMachineReadable -Line $r.Lines)
}

function Start-VBoxUnattendedInstall {
    <#
    .SYNOPSIS
        Bereitet eine unbeaufsichtigte OS-Installation vor und startet sie optional.
    .DESCRIPTION
        Das Cmdlet Start-VBoxUnattendedInstall bereitet eine unbeaufsichtigte Installation des
        Betriebssystems vor und startet die VM standardmäßig headless. Die Installation läuft danach
        ohne Eingriff durch.

        Passwörter werden ausschließlich über temporäre Dateien übergeben. Das Cmdlet erkennt selbst,
        ob die installierte VirtualBox-Version die Optionen --user-password-file (ab 7.1) oder
        --password-file erwartet.

        Die VM braucht ein DVD-Laufwerk. New-VBoxVM legt immer eins an.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER IsoPath
        Gibt das Installations-ISO an.
    .PARAMETER Credential
        Gibt den Benutzer an, der im Gast angelegt wird, mit Passwort. Ein Domänenpräfix wird
        ignoriert.
    .PARAMETER AdminPassword
        Gibt ein separates Administrator- bzw. root-Passwort an (ab VirtualBox 7.1). Ohne Angabe gilt
        das Benutzerpasswort.
    .PARAMETER FullUserName
        Gibt den vollständigen Anzeigenamen des Benutzers an.
    .PARAMETER Hostname
        Gibt den Hostnamen als FQDN an, z. B. win11.lab.local. Ohne Punkt wird .local angehängt.
    .PARAMETER ProductKey
        Gibt den Windows-Produktschlüssel an.
    .PARAMETER ImageIndex
        Gibt den Index des Windows-Images in der install.wim an, z. B. 6 für Windows 11 Pro auf vielen
        Medien.
    .PARAMETER Locale
        Gibt das Gebietsschema im Format ll_CC an, z. B. de_DE.
    .PARAMETER Country
        Gibt den Ländercode an, z. B. DE.
    .PARAMETER TimeZone
        Gibt die Zeitzone an, z. B. W. Europe Standard Time (Windows) oder Europe/Berlin.
    .PARAMETER Language
        Gibt die Sprache der Installationsoberfläche an, z. B. de-DE.
    .PARAMETER InstallGuestAdditions
        Installiert die Guest Additions im Anschluss an die Installation.
    .PARAMETER AdditionsIsoPath
        Gibt eine abweichende Guest-Additions-ISO an.
    .PARAMETER PostInstallCommand
        Gibt einen Befehl an, der am Ende der Installation im Gast ausgeführt wird.
    .PARAMETER StartVM
        Gibt an, wie die VM nach der Vorbereitung gestartet wird: Headless (Standard), GUI, Separate
        oder None (nicht starten).
    .EXAMPLE
        $cred = Get-Credential labadmin
        New-VBoxVM 'Win11-Lab' -OSType Windows11_64 -MemoryMB 8192 -CPUs 4 -DiskSizeGB 80 -Firmware EFI -EnableTpm -EnableSecureBoot
        Start-VBoxUnattendedInstall 'Win11-Lab' -IsoPath 'D:\ISO\Win11.iso' -Credential $cred `
            -Hostname 'win11-lab.lab.local' -Locale de_DE -Country DE `
            -TimeZone 'W. Europe Standard Time' -ImageIndex 6 -InstallGuestAdditions
        Wait-VBoxGuestAdditions 'Win11-Lab' -TimeoutSec 3600

        Windows 11 vollautomatisch installieren.
        Nach Wait-VBoxGuestAdditions ist der Gast bereit für Invoke-VBoxGuestCommand.
    .EXAMPLE
        Start-VBoxUnattendedInstall 'srv01' -IsoPath 'D:\ISO\ubuntu-24.04-live-server-amd64.iso' -Credential $cred `
            -Hostname 'srv01.lab.local' -TimeZone 'Europe/Berlin' -InstallGuestAdditions `
            -PostInstallCommand 'apt-get install -y openssh-server'

        Ubuntu-Server mit Nachinstallation.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.VM
        Ein Objekt mit Name, UUID, State, OSType, MemoryMB, CPUs, VRAMMB, Firmware, Groups,
        Description, ConfigFile, Directory und StateChanged.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage unattended install

        Ohne -Locale und -TimeZone verwendet VirtualBox en_US und UTC.
    .LINK
        New-VBoxVM
    .LINK
        Get-VBoxUnattendedIsoInfo
    .LINK
        Wait-VBoxGuestAdditions
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory)][string]$IsoPath,
        [Parameter(Mandatory)][pscredential]$Credential,
        [securestring]$AdminPassword,
        [string]$FullUserName,
        [string]$Hostname,
        [string]$ProductKey,
        [ValidateRange(1, 99)][int]$ImageIndex,
        [string]$Locale,
        [ValidatePattern('^[A-Za-z]{2}$')][string]$Country,
        [string]$TimeZone,
        [string]$Language,
        [switch]$InstallGuestAdditions,
        [string]$AdditionsIsoPath,
        [string]$PostInstallCommand,
        [ValidateSet('None', 'Headless', 'GUI', 'Separate')]
        [string]$StartVM = 'Headless'
    )
    process {
        $IsoPath = Resolve-VBoxHostPath $IsoPath
        if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) { throw "ISO nicht gefunden: $IsoPath" }
        if ($AdditionsIsoPath) { $AdditionsIsoPath = Resolve-VBoxHostPath $AdditionsIsoPath }
        if ($Hostname -and $Hostname -notmatch '\.') {
            $Hostname = "$Hostname.local"
            Write-Verbose "Hostname ist kein FQDN – verwende '$Hostname'."
        }
        if (-not $PSCmdlet.ShouldProcess($Name, "Unattended-Installation von '$IsoPath'")) { return }

        # Ab VBox 7.1 heißen die Optionen --user-password(-file)/--admin-password(-file), davor --password(-file)
        $help = Get-VBoxHelpText -Command 'unattended'
        $newStyle = if ($help -match '--user-password') { $true }
                    elseif ($help -match '--password') { $false }
                    else { (Get-VBoxVersionInternal).Version -ge [version]'7.1' }
        if ($AdminPassword -and -not $newStyle) { Write-Warning '-AdminPassword wird erst ab VirtualBox 7.1 unterstützt und ignoriert.' }

        $user = $Credential.UserName -replace '^.*\\', ''
        $files = @()
        try {
            $pwFile = New-VBoxPasswordFile -Password $Credential.Password
            $files += $pwFile
            $cli = @('unattended', 'install', $Name, '--iso', $IsoPath, '--user', $user)
            if ($newStyle) {
                $cli += '--user-password-file', $pwFile
                if ($AdminPassword) {
                    $adminFile = New-VBoxPasswordFile -Password $AdminPassword
                    $files += $adminFile
                    $cli += '--admin-password-file', $adminFile
                }
            }
            else {
                $cli += '--password-file', $pwFile
            }
            if ($FullUserName)          { $cli += '--full-user-name', $FullUserName }
            if ($Hostname)              { $cli += '--hostname', $Hostname }
            if ($ProductKey)            { $cli += '--key', $ProductKey }
            if ($ImageIndex)            { $cli += '--image-index', $ImageIndex }
            if ($Locale)                { $cli += '--locale', $Locale }
            if ($Country)               { $cli += '--country', $Country.ToUpperInvariant() }
            if ($TimeZone)              { $cli += '--time-zone', $TimeZone }
            if ($Language)              { $cli += '--language', $Language }
            if ($InstallGuestAdditions) { $cli += '--install-additions' }
            if ($AdditionsIsoPath)      { $cli += '--additions-iso', $AdditionsIsoPath }
            if ($PostInstallCommand)    { $cli += '--post-install-command', $PostInstallCommand }
            if ($StartVM -ne 'None')    { $cli += '--start-vm', $StartVM.ToLowerInvariant() }

            $r = Invoke-VBoxManageCore -ArgumentList $cli
            Write-Verbose ($r.Lines -join [Environment]::NewLine)
        }
        finally {
            foreach ($f in $files) { Remove-VBoxPasswordFile -Path $f }
        }
        Get-VBoxVM -Name $Name
    }
}

#endregion

#region Guest Properties / Guest Additions

function Get-VBoxGuestProperty {
    <#
    .SYNOPSIS
        Liest Guest Properties. Mit -Property wird nur der Wert (string) geliefert, sonst alle als Objekte.
    .DESCRIPTION
        Das Cmdlet Get-VBoxGuestProperty liest Guest Properties. Das sind Schlüssel/Wert-Paare, die
        Host und Guest Additions austauschen.

        Mit -Property gibt das Cmdlet nur den Wert als Zeichenfolge zurück, oder nichts, wenn er nicht
        gesetzt ist. Ohne -Property gibt es alle Properties als Objekte zurück.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Property
        Gibt den vollständigen Namen einer einzelnen Property an, z. B.
        /VirtualBox/GuestInfo/OS/Product.
    .PARAMETER Pattern
        Filtert die aufgezählten Properties nach Muster, z. B. /VirtualBox/GuestInfo/Net/*.
    .EXAMPLE
        Get-VBoxGuestProperty 'Win11-Lab' '/VirtualBox/GuestInfo/OS/Product'

        Betriebssystem des Gasts.
        Windows 11
    .EXAMPLE
        Get-VBoxGuestProperty 'Win11-Lab' -Pattern '/VirtualBox/GuestInfo/Net/*'

        Alle Netzwerk-Properties.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        System.String
        Mit -Property.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Ohne -Property: Objekte mit Property, Value, Timestamp und Flags.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage guestproperty get | enumerate
    .LINK
        Set-VBoxGuestProperty
    .LINK
        Get-VBoxGuestIPAddress
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Single')]
        [string]$Property,
        [Parameter(ParameterSetName = 'All')]
        [string]$Pattern
    )
    process {
        if ($Property) {
            $r = Invoke-VBoxManageCore -ArgumentList 'guestproperty', 'get', $Name, $Property
            foreach ($l in $r.Lines) { if ($l -match '^Value:\s?(?<v>.*)$') { return $Matches['v'] } }
            return
        }
        $cli = @('guestproperty', 'enumerate', $Name)
        if ($Pattern) { $cli += '--patterns', $Pattern }
        foreach ($l in (Invoke-VBoxManageCore -ArgumentList $cli).Lines) {
            if ($l -match '^Name:\s*(?<n>[^,]+),\s*value:\s*(?<v>.*?),\s*timestamp:\s*(?<t>\d+),\s*flags:\s*(?<f>.*)$') {
                # Format VBox 6.x
                [pscustomobject]@{ Property = $Matches['n']; Value = $Matches['v']; Timestamp = $Matches['t']; Flags = $Matches['f'] }
            }
            elseif ($l -match "^(?<n>/\S+)\s*=\s*'(?<v>.*)'(?:\s*@\s*(?<t>[^,\s]+),?)?\s*(?<f>.*)$") {
                # Format VBox 7.x
                [pscustomobject]@{ Property = $Matches['n']; Value = $Matches['v']; Timestamp = $Matches['t']; Flags = $Matches['f'].Trim() }
            }
        }
    }
}

function Set-VBoxGuestProperty {
    <#
    .SYNOPSIS
        Setzt oder löscht (-Value weglassen) eine Guest Property.
    .DESCRIPTION
        Das Cmdlet Set-VBoxGuestProperty setzt eine Guest Property. Ohne -Value wird die Property
        gelöscht.

        Eigene Properties eignen sich, um Konfiguration an Skripte im Gast zu übergeben. Im Gast liest
        man sie mit VBoxControl guestproperty get.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Property
        Gibt den Namen der Property an, z. B. /Lab/Role.
    .PARAMETER Value
        Gibt den Wert an. Ohne Angabe wird die Property gelöscht.
    .PARAMETER Flags
        Gibt Flags an, z. B. TRANSIENT oder RDONLYGUEST.
    .EXAMPLE
        Set-VBoxGuestProperty 'Win11-Lab' '/Lab/Role' 'Client'

        Rolle an den Gast übergeben.
    .EXAMPLE
        Set-VBoxGuestProperty 'Win11-Lab' '/Lab/Role'

        Property löschen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage guestproperty set | delete
    .LINK
        Get-VBoxGuestProperty
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory, Position = 1)][string]$Property,
        [Parameter(Position = 2)][string]$Value,
        [string]$Flags
    )
    process {
        if (-not $PSCmdlet.ShouldProcess($Name, "Guest Property '$Property' setzen")) { return }
        if ($PSBoundParameters.ContainsKey('Value')) {
            $cli = @('guestproperty', 'set', $Name, $Property, $Value)
            if ($Flags) { $cli += '--flags', $Flags }
        }
        else {
            $cli = @('guestproperty', 'delete', $Name, $Property)
        }
        $null = Invoke-VBoxManageCore -ArgumentList $cli
    }
}

function Wait-VBoxGuestAdditions {
    <#
    .SYNOPSIS
        Wartet, bis die Guest Additions in der laufenden VM den gewünschten Run-Level erreicht haben.
    .DESCRIPTION
        Das Cmdlet Wait-VBoxGuestAdditions wartet, bis die Guest Additions in der laufenden VM den
        gewünschten Run-Level erreicht haben. Dann ist der Gast bereit für Guest Control, Dateikopien
        und Guest Properties.

        Läuft die VM nicht, löst das Cmdlet sofort einen Fehler aus.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER RunLevel
        Gibt den Ziel-Run-Level an: System (Dienst gestartet), Userland (Standard, Guest Control
        verfügbar) oder Desktop (ein Benutzer ist angemeldet).
    .PARAMETER TimeoutSec
        Gibt an, wie viele Sekunden das Cmdlet maximal wartet. Nach Ablauf wird ein Fehler ausgelöst.
    .PARAMETER PollIntervalSec
        Gibt an, in welchem Abstand (Sekunden) der Zustand abgefragt wird.
    .EXAMPLE
        Wait-VBoxGuestAdditions 'Win11-Lab' -TimeoutSec 3600

        Nach der Installation warten.
        VMName    RunLevel Version
        ------    -------- -------
        Win11-Lab        2 7.1.4 r165100
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Objekt mit VMName, RunLevel und Version.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage showvminfo <vm> --machinereadable
        (GuestAdditionsRunLevel)
    .LINK
        Start-VBoxVM
    .LINK
        Invoke-VBoxGuestCommand
    .LINK
        Start-VBoxUnattendedInstall
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [ValidateSet('System', 'Userland', 'Desktop')][string]$RunLevel = 'Userland',
        [int]$TimeoutSec = 600,
        [int]$PollIntervalSec = 5
    )
    process {
        $levels   = @{ System = 1; Userland = 2; Desktop = 3 }
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        do {
            $info = Get-VBoxVMInfo -Name $Name
            if ($script:VBoxOfflineStates -contains $info['VMState']) { throw "VM '$Name' läuft nicht (Zustand: $($info['VMState']))." }
            $rl = ConvertTo-VBoxInt $info['GuestAdditionsRunLevel']
            if ($rl -ge $levels[$RunLevel]) {
                return [pscustomobject]@{ VMName = $Name; RunLevel = $rl; Version = $info['GuestAdditionsVersion'] }
            }
            Start-Sleep -Seconds $PollIntervalSec
        } while ((Get-Date) -lt $deadline)
        throw "Zeitüberschreitung: Guest Additions in '$Name' haben Run-Level '$RunLevel' nicht innerhalb von $TimeoutSec s erreicht."
    }
}

function Get-VBoxGuestIPAddress {
    <#
    .SYNOPSIS
        Liefert die IP-Adressen des Gasts (benötigt Guest Additions).
    .DESCRIPTION
        Das Cmdlet Get-VBoxGuestIPAddress gibt die IPv4-Adressen zurück, die die Guest Additions
        melden. Das ist vor allem bei Bridged- oder Host-Only-Netzen nützlich, wenn die Adresse per
        DHCP vergeben wurde.

        Mit -Wait wartet das Cmdlet, bis mindestens eine Adresse gemeldet wird.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Wait
        Wartet, bis mindestens eine IPv4-Adresse gemeldet wird.
    .PARAMETER TimeoutSec
        Gibt an, wie lange bei -Wait maximal gewartet wird.
    .EXAMPLE
        $ip = (Get-VBoxGuestIPAddress 'srv01' -Wait | Select-Object -First 1).IPv4
        ssh admin@$ip

        Adresse ermitteln und verbinden.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Objekt mit VMName, Index, IPv4, Netmask, MacAddress und Status.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage guestproperty enumerate
    .LINK
        Get-VBoxGuestProperty
    .LINK
        Get-VBoxVMNetworkAdapter
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [switch]$Wait,
        [int]$TimeoutSec = 600
    )
    process {
        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        do {
            $props = @{}
            foreach ($p in Get-VBoxGuestProperty -Name $Name -Pattern '/VirtualBox/GuestInfo/Net/*') { $props[$p.Property] = $p.Value }
            $count  = ConvertTo-VBoxInt $props['/VirtualBox/GuestInfo/Net/Count']
            $result = @(for ($i = 0; $i -lt [int]$count; $i++) {
                $base = "/VirtualBox/GuestInfo/Net/$i"
                if (-not $props["$base/V4/IP"]) { continue }
                [pscustomobject]@{
                    VMName     = $Name
                    Index      = $i
                    IPv4       = $props["$base/V4/IP"]
                    Netmask    = $props["$base/V4/Netmask"]
                    MacAddress = Format-VBoxMac $props["$base/MAC"]
                    Status     = $props["$base/Status"]
                }
            })
            if ($result.Count -or -not $Wait) { return $result }
            Start-Sleep -Seconds 5
        } while ((Get-Date) -lt $deadline)
        throw "Zeitüberschreitung: '$Name' hat innerhalb von $TimeoutSec s keine IP-Adresse gemeldet."
    }
}

#endregion

#region Guest Control

function Invoke-VBoxGuestCommand {
    <#
    .SYNOPSIS
        Führt ein Programm im Gast aus und liefert ExitCode, StdOut und StdErr.
    .DESCRIPTION
        Das Cmdlet Invoke-VBoxGuestCommand führt ein Programm im Gast aus, ohne dass dafür eine
        Netzwerkverbindung nötig ist. Es gibt Exit-Code, Standardausgabe und Fehlerausgabe zurück.

        Voraussetzung sind laufende Guest Additions (siehe Wait-VBoxGuestAdditions). Bei normal
        beendeten Prozessen entspricht ExitCode dem Exit-Code des Gastprozesses.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Credential
        Gibt das Benutzerkonto im Gastbetriebssystem an. Zulässig sind Benutzer, DOMÄNE\Benutzer und
        .\Benutzer. Das Passwort wird nur über eine temporäre Datei an VBoxManage übergeben, die
        danach überschrieben und gelöscht wird.
    .PARAMETER FilePath
        Gibt den vollständigen Pfad der ausführbaren Datei im Gast an, z. B.
        C:\Windows\System32\cmd.exe oder /bin/bash.
    .PARAMETER ArgumentList
        Gibt die Argumente für das Programm an. Jedes Element wird als eigenes Argument übergeben.
    .PARAMETER Environment
        Gibt zusätzliche Umgebungsvariablen für den Prozess als Hashtable an.
    .PARAMETER TimeoutSec
        Gibt an, nach wie vielen Sekunden der Gastprozess abgebrochen wird. Standardmäßig gibt es kein
        Zeitlimit.
    .PARAMETER ThrowOnError
        Löst einen Fehler aus, wenn der Exit-Code ungleich 0 ist.
    .EXAMPLE
        $cred = Get-Credential labadmin
        $r = Invoke-VBoxGuestCommand 'Win11-Lab' -Credential $cred -FilePath 'C:\Windows\System32\cmd.exe' -ArgumentList '/c', 'ipconfig /all'
        $r.StdOut

        Befehl in einem Windows-Gast.
    .EXAMPLE
        Copy-VBoxGuestItem 'Win11-Lab' -Credential $cred -Path .\setup.ps1 -Destination 'C:\Deploy'
        Invoke-VBoxGuestCommand 'Win11-Lab' -Credential $cred -ThrowOnError `
            -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
            -ArgumentList '-ExecutionPolicy', 'Bypass', '-File', 'C:\Deploy\setup.ps1'

        Skript ausführen und bei Fehler abbrechen.
    .EXAMPLE
        (Invoke-VBoxGuestCommand 'srv01' -Credential $cred -FilePath /bin/bash -ArgumentList '-c', 'uname -a').StdOut

        Befehl in einem Linux-Gast.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.GuestCommandResult
        Objekt mit VMName, FilePath, ExitCode, StdOut und StdErr.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage guestcontrol <vm> run

        In Windows-Gästen gilt die Benutzerkontensteuerung: Lokale Administratoren außer dem
        integrierten Konto Administrator erhalten nur ein gefiltertes Token. Für administrative
        Befehle verwenden Sie das integrierte Administratorkonto oder passen die UAC-Remote-
        Einschränkungen an.
    .LINK
        Wait-VBoxGuestAdditions
    .LINK
        Copy-VBoxGuestItem
    .LINK
        New-VBoxGuestDirectory
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory)][pscredential]$Credential,
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList,
        [hashtable]$Environment,
        [int]$TimeoutSec,
        [switch]$ThrowOnError
    )
    process {
        if (-not $PSCmdlet.ShouldProcess($Name, "Im Gast ausführen: $FilePath $($ArgumentList -join ' ')")) { return }
        $pwFile = New-VBoxPasswordFile -Password $Credential.Password
        try {
            $cli = @('guestcontrol', $Name, 'run') + (Get-VBoxGuestCredentialArgument -Credential $Credential -PasswordFile $pwFile)
            $cli += '--exe', $FilePath, '--wait-stdout', '--wait-stderr'
            if ($TimeoutSec) { $cli += '--timeout', ($TimeoutSec * 1000) }
            if ($Environment) { foreach ($k in $Environment.Keys) { $cli += '--putenv', ('{0}={1}' -f $k, $Environment[$k]) } }
            $cli += '--', $FilePath
            if ($ArgumentList) { $cli += $ArgumentList }
            $r = Invoke-VBoxManageCore -ArgumentList $cli -NoThrow
        }
        finally {
            Remove-VBoxPasswordFile -Path $pwFile
        }
        $out = [pscustomobject]@{
            PSTypeName = 'VBoxPS.GuestCommandResult'
            VMName     = $Name
            FilePath   = $FilePath
            ExitCode   = $r.ExitCode
            StdOut     = $r.StdOut
            StdErr     = $r.StdErr
        }
        if ($ThrowOnError -and $r.ExitCode -ne 0) {
            throw "Gastbefehl '$FilePath' in '$Name' fehlgeschlagen (Exit-Code $($r.ExitCode)): $($r.StdErr.Trim())"
        }
        $out
    }
}

function Copy-VBoxGuestItem {
    <#
    .SYNOPSIS
        Kopiert Dateien/Ordner zwischen Host und Gast.
    .DESCRIPTION
        Das Cmdlet Copy-VBoxGuestItem kopiert Dateien und Ordner zwischen Host und Gast. Dafür sind
        keine Netzwerkfreigaben nötig.

        Standardmäßig wird vom Host in den Gast kopiert, mit -FromGuest umgekehrt. Ein lokaler
        Zielordner wird bei Bedarf angelegt.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Credential
        Gibt das Benutzerkonto im Gastbetriebssystem an. Zulässig sind Benutzer, DOMÄNE\Benutzer und
        .\Benutzer. Das Passwort wird nur über eine temporäre Datei an VBoxManage übergeben, die
        danach überschrieben und gelöscht wird.
    .PARAMETER Path
        Gibt eine oder mehrere Quellen an: Host-Pfade beim Kopieren in den Gast, Gast-Pfade mit
        -FromGuest.
    .PARAMETER Destination
        Gibt den Zielordner an, im Gast oder mit -FromGuest auf dem Host.
    .PARAMETER ToGuest
        Kopiert vom Host in den Gast (Standard).
    .PARAMETER FromGuest
        Kopiert vom Gast auf den Host.
    .PARAMETER Recurse
        Kopiert Ordner rekursiv.
    .EXAMPLE
        Copy-VBoxGuestItem 'Win11-Lab' -Credential $cred -Path .\Scripts -Destination 'C:\Deploy' -Recurse

        Skriptordner in den Gast kopieren.
    .EXAMPLE
        Copy-VBoxGuestItem 'Win11-Lab' -Credential $cred -FromGuest -Path 'C:\Windows\Logs\CBS\CBS.log' -Destination .\Logs

        Logdatei vom Gast holen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage guestcontrol <vm> copyto | copyfrom
    .LINK
        Invoke-VBoxGuestCommand
    .LINK
        New-VBoxGuestDirectory
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ToGuest')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory)][pscredential]$Credential,
        [Parameter(Mandatory)][string[]]$Path,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(ParameterSetName = 'ToGuest')][switch]$ToGuest,
        [Parameter(Mandatory, ParameterSetName = 'FromGuest')][switch]$FromGuest,
        [switch]$Recurse
    )
    process {
        if ($FromGuest) {
            $verb   = 'copyfrom'
            $Destination = Resolve-VBoxHostPath $Destination
            if (-not (Test-Path -LiteralPath $Destination)) { $null = New-Item -ItemType Directory -Path $Destination -Force }
            $source = $Path
        }
        else {
            $verb   = 'copyto'
            $source = foreach ($p in $Path) {
                $full = Resolve-VBoxHostPath $p
                if (-not (Test-Path -LiteralPath $full)) { throw "Quelle nicht gefunden: $full" }
                $full
            }
        }
        if (-not $PSCmdlet.ShouldProcess($Name, "$verb $($source -join ', ') -> $Destination")) { return }

        $pwFile = New-VBoxPasswordFile -Password $Credential.Password
        try {
            $cli = @('guestcontrol', $Name, $verb) + (Get-VBoxGuestCredentialArgument -Credential $Credential -PasswordFile $pwFile)
            if ($Recurse) { $cli += '--recursive' }
            $cli += '--target-directory', $Destination
            $cli += $source
            $null = Invoke-VBoxManageCore -ArgumentList $cli
        }
        finally {
            Remove-VBoxPasswordFile -Path $pwFile
        }
    }
}

function New-VBoxGuestDirectory {
    <#
    .SYNOPSIS
        Legt im Gast ein Verzeichnis an (inkl. übergeordneter Ordner).
    .DESCRIPTION
        Das Cmdlet New-VBoxGuestDirectory legt im Gast einen oder mehrere Ordner an. Fehlende
        übergeordnete Ordner werden mit angelegt.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .PARAMETER Credential
        Gibt das Benutzerkonto im Gastbetriebssystem an. Zulässig sind Benutzer, DOMÄNE\Benutzer und
        .\Benutzer. Das Passwort wird nur über eine temporäre Datei an VBoxManage übergeben, die
        danach überschrieben und gelöscht wird.
    .PARAMETER Path
        Gibt einen oder mehrere Ordnerpfade im Gast an.
    .EXAMPLE
        New-VBoxGuestDirectory 'Win11-Lab' -Credential $cred -Path 'C:\Deploy\Logs', 'C:\Deploy\Tools'

        Ordnerstruktur anlegen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage guestcontrol <vm> mkdir --parents
    .LINK
        Copy-VBoxGuestItem
    .LINK
        Invoke-VBoxGuestCommand
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name,
        [Parameter(Mandatory)][pscredential]$Credential,
        [Parameter(Mandatory)][string[]]$Path
    )
    process {
        if (-not $PSCmdlet.ShouldProcess($Name, "Verzeichnis anlegen: $($Path -join ', ')")) { return }
        $pwFile = New-VBoxPasswordFile -Password $Credential.Password
        try {
            $cli = @('guestcontrol', $Name, 'mkdir') + (Get-VBoxGuestCredentialArgument -Credential $Credential -PasswordFile $pwFile)
            $cli += '--parents'
            $cli += $Path
            $null = Invoke-VBoxManageCore -ArgumentList $cli
        }
        finally {
            Remove-VBoxPasswordFile -Path $pwFile
        }
    }
}

#endregion
