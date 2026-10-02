function Get-VBoxManagePath {
    <#
    .SYNOPSIS
        Liefert den Pfad der verwendeten VBoxManage-Binary.
    .DESCRIPTION
        Das Cmdlet Get-VBoxManagePath gibt den vollständigen Pfad der VBoxManage-Binary zurück, die
        das Modul verwendet.

        Die Binary wird beim ersten Aufruf in dieser Reihenfolge gesucht: ein mit Set-VBoxManagePath
        gesetzter Pfad, die Umgebungsvariable VBOXPS_VBOXMANAGE, VBOX_MSI_INSTALL_PATH,
        VBOX_INSTALL_PATH, die Standard-Installationspfade (%ProgramFiles%\Oracle\VirtualBox,
        /usr/bin, /usr/local/bin, /Applications/VirtualBox.app) und zuletzt PATH. Wird keine Binary
        gefunden, löst das Cmdlet einen Fehler aus.
    .EXAMPLE
        Get-VBoxManagePath

        Verwendeten VBoxManage-Pfad anzeigen.
        Gibt z. B. C:\Program Files\Oracle\VirtualBox\VBoxManage.exe zurück.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.String
        Der vollständige Pfad zu VBoxManage.
    .LINK
        Set-VBoxManagePath
    .LINK
        Get-VBoxVersion
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    Resolve-VBoxManagePath
}

function Set-VBoxManagePath {
    <#
    .SYNOPSIS
        Legt fest, welche VBoxManage-Binary verwendet wird.
    .DESCRIPTION
        Das Cmdlet Set-VBoxManagePath legt für die aktuelle Sitzung fest, welche VBoxManage-Binary das
        Modul verwendet. Das ist nötig, wenn VirtualBox an einem nicht standardmäßigen Ort installiert
        ist oder mehrere Versionen parallel vorhanden sind.

        Beim Setzen werden die zwischengespeicherte Version, die Hilfetexte und die OS-Typ-Liste
        verworfen. Für eine dauerhafte Einstellung setzen Sie die Umgebungsvariable VBOXPS_VBOXMANAGE.
    .PARAMETER Path
        Gibt den Pfad zur Datei VBoxManage(.exe) oder zum VirtualBox-Installationsordner an. Relative
        Pfade werden gegen das aktuelle Verzeichnis aufgelöst.
    .EXAMPLE
        Set-VBoxManagePath 'D:\Tools\VirtualBox'

        Installationsordner angeben.
        Verwendet D:\Tools\VirtualBox\VBoxManage.exe für alle weiteren Aufrufe.
    .EXAMPLE
        $env:VBOXPS_VBOXMANAGE = 'D:\Tools\VirtualBox\VBoxManage.exe'

        Pfad dauerhaft über das Profil setzen.
        In das PowerShell-Profil eingetragen, gilt die Einstellung für jede neue Sitzung.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        None
        Standardmäßig erzeugt dieses Cmdlet keine Ausgabe.
    .LINK
        Get-VBoxManagePath
    .LINK
        Get-VBoxVersion
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory, Position = 0)][string]$Path)

    $resolved = Resolve-VBoxHostPath -Path $Path
    if (Test-Path -LiteralPath $resolved -PathType Container) {
        $exe = if ($script:IsWin) { 'VBoxManage.exe' } else { 'VBoxManage' }
        $resolved = Join-Path -Path $resolved -ChildPath $exe
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "VBoxManage nicht gefunden: $resolved" }

    if ($PSCmdlet.ShouldProcess($resolved, 'VBoxManage-Pfad setzen')) {
        $script:VBoxManagePath  = $resolved
        $script:VBoxVersion     = $null
        $script:VBoxHelpCache   = @{}
        $script:VBoxOSTypeCache = $null
    }
}

function Get-VBoxVersion {
    <#
    .SYNOPSIS
        Liefert die installierte VirtualBox-Version.
    .DESCRIPTION
        Das Cmdlet Get-VBoxVersion gibt die installierte VirtualBox-Version zurück. Das Ergebnis wird
        pro Sitzung zwischengespeichert.

        Mehrere Funktionen des Moduls prüfen die Version intern, z. B. für TPM/Secure Boot oder Stop-
        VBoxVM -Mode Shutdown (beides ab 7.0).
    .EXAMPLE
        Get-VBoxVersion

        Version anzeigen.
    .EXAMPLE
        if ((Get-VBoxVersion).Version -lt [version]'7.0') {
            throw 'Dieses Skript benötigt VirtualBox 7.0 oder neuer.'
        }

        Mindestversion im Skript prüfen.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        VBoxPS.Version
        Objekt mit Version ([version]), Revision, Raw (Originalausgabe) und Path.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage --version
    .LINK
        Get-VBoxManagePath
    .LINK
        Get-VBoxHostInfo
    #>
    [CmdletBinding()]
    param()
    Get-VBoxVersionInternal
}

function Invoke-VBoxManage {
    <#
    .SYNOPSIS
        Ruft VBoxManage direkt auf – für alles, was das Modul nicht abdeckt.
    .DESCRIPTION
        Das Cmdlet Invoke-VBoxManage ruft VBoxManage mit beliebigen Argumenten auf. Verwenden Sie es
        für alles, was das Modul nicht direkt abdeckt.

        Ohne -Raw gibt das Cmdlet die Ausgabezeilen zurück und löst bei einem Exit-Code ungleich 0
        einen Fehler mit der Meldung von VBoxManage aus. Mit -Raw erhalten Sie ein Ergebnisobjekt und
        es wird kein Fehler ausgelöst.

        Die Argumente werden korrekt maskiert, Leerzeichen und Anführungszeichen in Werten sind also
        unproblematisch.
    .PARAMETER ArgumentList
        Gibt die Argumente für VBoxManage an. Alle nicht benannten Argumente werden gesammelt,
        Optionen wie --machinereadable können direkt geschrieben werden.
    .PARAMETER Raw
        Gibt statt der Ausgabezeilen ein VBoxPS.CommandResult-Objekt mit ExitCode, StdOut, StdErr und
        Lines zurück. Fehler werden nicht als Exception ausgelöst.
    .EXAMPLE
        Invoke-VBoxManage list extpacks

        Installierte Extension Packs anzeigen.
    .EXAMPLE
        $r = Invoke-VBoxManage showvminfo 'Win11' --machinereadable -Raw
        if ($r.ExitCode -ne 0) { Write-Warning $r.StdErr }

        Exit-Code selbst auswerten.
    .EXAMPLE
        Invoke-VBoxManage hostonlynet add --name LabNet --netmask 255.255.255.0 --lower-ip 192.168.60.100 --upper-ip 192.168.60.200

        Host-Only-Netzwerk unter macOS anlegen.
        VirtualBox 7 verwendet unter macOS Host-Only-Netzwerke statt Host-Only-Interfaces.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.String
        Die Ausgabezeilen von VBoxManage.
    .OUTPUTS
        VBoxPS.CommandResult
        Mit -Raw.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage <Argumente>

        Mit -Verbose zeigen alle Cmdlets des Moduls den exakt ausgeführten VBoxManage-Aufruf.
    .LINK
        Get-VBoxManagePath
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [string[]]$ArgumentList,
        [switch]$Raw
    )
    $r = Invoke-VBoxManageCore -ArgumentList $ArgumentList -NoThrow:$Raw
    if ($Raw) { $r } else { $r.Lines }
}

function Get-VBoxVM {
    <#
    .SYNOPSIS
        Listet registrierte VMs auf.
    .DESCRIPTION
        Das Cmdlet Get-VBoxVM ruft die registrierten virtuellen Maschinen ab. Ohne Parameter werden
        alle VMs zurückgegeben.

        Sie können VMs über Namen (mit Platzhaltern) oder UUID auswählen. Wird ein Name ohne
        Platzhalter nicht gefunden, schreibt das Cmdlet einen nicht beendenden Fehler.

        Die Objekte lassen sich an die meisten anderen Cmdlets des Moduls weitergeben.
    .PARAMETER Name
        Gibt die Namen oder UUIDs der abzurufenden VMs an. Platzhalter sind zulässig. Standardmäßig
        werden alle VMs abgerufen.
    .PARAMETER Running
        Gibt nur laufende und pausierte VMs zurück.
    .PARAMETER Detailed
        Fügt die vollständige showvminfo-Ausgabe als Eigenschaft Info (geordnetes Dictionary) hinzu.
    .EXAMPLE
        Get-VBoxVM

        Alle VMs abrufen.
        Name       State    OSType              MemoryMB CPUs
        ----       -----    ------              -------- ----
        Win11-Lab  running  Windows 11 (64-bit)     8192    4
        srv01      poweroff Ubuntu (64-bit)         4096    2
    .EXAMPLE
        Get-VBoxVM 'Lab-*'

        VMs über Platzhalter auswählen.
    .EXAMPLE
        Get-VBoxVM -Running | Stop-VBoxVM -Wait

        Alle laufenden VMs sauber herunterfahren.
    .EXAMPLE
        (Get-VBoxVM 'Win11-Lab' -Detailed).Info['GuestAdditionsVersion']

        Einzelne Rohwerte abfragen.
    .INPUTS
        System.String
        Sie können VM-Namen über die Pipeline übergeben.
    .OUTPUTS
        VBoxPS.VM
        Ein Objekt mit Name, UUID, State, OSType, MemoryMB, CPUs, VRAMMB, Firmware, Groups,
        Description, ConfigFile, Directory und StateChanged.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage list vms / showvminfo --machinereadable
    .LINK
        Get-VBoxVMInfo
    .LINK
        Start-VBoxVM
    .LINK
        Stop-VBoxVM
    .LINK
        New-VBoxVM
    #>
    [CmdletBinding()]
    [OutputType('VBoxPS.VM')]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('VMName', 'UUID')]
        [SupportsWildcards()]
        [string[]]$Name = '*',
        [switch]$Running,
        [switch]$Detailed
    )
    begin {
        $all = @(Get-VBoxVMList)
        if ($Running) {
            $runningIds = @(Get-VBoxVMList -Running | ForEach-Object UUID)
            $all = @($all | Where-Object { $runningIds -contains $_.UUID })
        }
        $seen = @{}
    }
    process {
        foreach ($n in $Name) {
            $hits = @($all | Where-Object { $_.Name -eq $n -or $_.UUID -eq $n -or $_.Name -like $n })
            if (-not $hits -and -not [WildcardPattern]::ContainsWildcardCharacters($n)) {
                Write-Error -Message "VM '$n' wurde nicht gefunden." -Category ObjectNotFound -TargetObject $n
                continue
            }
            foreach ($vm in $hits) {
                if ($seen.ContainsKey($vm.UUID)) { continue }
                $seen[$vm.UUID] = $true
                try {
                    ConvertTo-VBoxVMObject -Info (Get-VBoxVMInfo -Name $vm.UUID) -IncludeInfo:$Detailed
                }
                catch { Write-Error -ErrorRecord $_ }
            }
        }
    }
}

function Get-VBoxVMInfo {
    <#
    .SYNOPSIS
        Liefert alle Eigenschaften einer VM (showvminfo --machinereadable) als geordnetes Dictionary.
    .DESCRIPTION
        Das Cmdlet Get-VBoxVMInfo gibt alle Eigenschaften einer VM als geordnetes Dictionary zurück,
        genau so, wie VBoxManage sie liefert. Maskierte Werte werden entmaskiert.

        Verwenden Sie das Cmdlet, wenn Sie Werte brauchen, die Get-VBoxVM nicht als eigene Eigenschaft
        bereitstellt.
    .PARAMETER Name
        Gibt den Namen oder die UUID der VM an. Sie können auch Objekte von Get-VBoxVM über die
        Pipeline übergeben.
    .EXAMPLE
        (Get-VBoxVMInfo 'Win11-Lab')['VMState']

        Zustand einer VM abfragen.
    .EXAMPLE
        (Get-VBoxVMInfo 'srv01').GetEnumerator() | Where-Object Key -like 'nic*'

        Alle Schlüssel mit 'nic' anzeigen.
    .INPUTS
        System.String
        Sie können VM-Namen und Objekte mit einer Eigenschaft Name oder VMName (z. B. von Get-VBoxVM)
        über die Pipeline übergeben.
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
        Schlüssel/Wert-Paare der VM-Konfiguration.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage showvminfo <vm> --machinereadable

        Die Schlüsselnamen können sich zwischen VirtualBox-Versionen unterscheiden.
    .LINK
        Get-VBoxVM
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('VMName')]
        [string]$Name
    )
    process {
        ConvertFrom-VBoxMachineReadable -Line (Get-VBoxVMInfoLines -Name $Name)
    }
}

function Get-VBoxOSType {
    <#
    .SYNOPSIS
        Listet die von VirtualBox unterstützten Gast-OS-Typen (für New-VBoxVM -OSType).
    .DESCRIPTION
        Das Cmdlet Get-VBoxOSType listet die Gastbetriebssystem-Typen, die VirtualBox kennt. Die ID
        verwenden Sie für New-VBoxVM -OSType und Set-VBoxVM -OSType.

        Die Liste wird pro Sitzung zwischengespeichert. Für -OSType steht außerdem Tab-
        Vervollständigung zur Verfügung.
    .PARAMETER Filter
        Filtert nach ID oder Beschreibung. Platzhalter sind zulässig.
    .EXAMPLE
        Get-VBoxOSType '*Windows*11*' | Select-Object ID, Description

        Windows-11-Typ finden.
        ID           Description
        --           -----------
        Windows11_64 Windows 11 (64-bit)
    .EXAMPLE
        Get-VBoxOSType | Where-Object FamilyID -eq 'Linux'

        Alle Linux-Typen anzeigen.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Ein Objekt pro OS-Typ mit den Eigenschaften aus list ostypes (u. a. ID, Description,
        FamilyID).
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage list ostypes
    .LINK
        New-VBoxVM
    .LINK
        Set-VBoxVM
    #>
    [CmdletBinding()]
    param([Parameter(Position = 0)][SupportsWildcards()][string]$Filter = '*')
    if (-not $script:VBoxOSTypeCache) {
        $script:VBoxOSTypeCache = @(ConvertFrom-VBoxList -Line (Invoke-VBoxManageCore -ArgumentList 'list', 'ostypes').Lines)
    }
    $script:VBoxOSTypeCache | Where-Object { $_.ID -like $Filter -or $_.Description -like $Filter }
}

function Get-VBoxHostInfo {
    <#
    .SYNOPSIS
        Liefert Informationen über den VirtualBox-Host (CPU, RAM, OS).
    .DESCRIPTION
        Das Cmdlet Get-VBoxHostInfo gibt Informationen über den VirtualBox-Host zurück, z. B.
        Prozessoren, Arbeitsspeicher und Betriebssystem.
    .EXAMPLE
        Get-VBoxHostInfo

        Hostinformationen anzeigen.
    .INPUTS
        None
        Sie können keine Objekte über die Pipeline an dieses Cmdlet übergeben.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Ein Objekt mit den Eigenschaften aus list hostinfo. Die Namen werden in PascalCase
        umgewandelt, z. B. ProcessorCount, MemorySize.
    .NOTES
        Zugrunde liegender Aufruf: VBoxManage list hostinfo
    .LINK
        Get-VBoxVersion
    #>
    [CmdletBinding()]
    param()
    # Ausgabe besteht aus mehreren Blöcken ("Host Information:" + Werte) -> zu einem Objekt zusammenführen
    $merged = [ordered]@{}
    foreach ($block in ConvertFrom-VBoxList -Line (Invoke-VBoxManageCore -ArgumentList 'list', 'hostinfo').Lines) {
        foreach ($prop in $block.PSObject.Properties) {
            if ($prop.Value -ne '' -and -not $merged.Contains($prop.Name)) { $merged[$prop.Name] = $prop.Value }
        }
    }
    [pscustomobject]$merged
}
