# VBoxPS

PowerShell-Modul zur Steuerung von Oracle VirtualBox – VM-Lifecycle, Snapshots, Erstellen/Klonen/Löschen,
Netzwerk, Storage, Unattended Install und Guest Control.

- Windows PowerShell 5.1 und PowerShell 7+ (Windows, Linux, macOS)
- VirtualBox 6.1 und 7.x (einzelne Funktionen ab 7.0, siehe unten)
- Pipeline-fähig, `-WhatIf`/`-Confirm` bei allen ändernden Befehlen, Tab-Vervollständigung für VM-Namen und OS-Typen

## Installation

```powershell
# Ordner VBoxPS in einen Modulpfad kopieren, z. B.:
Copy-Item .\VBoxPS "$HOME\Documents\WindowsPowerShell\Modules\" -Recurse   # PS 5.1
Copy-Item .\VBoxPS "$HOME\Documents\PowerShell\Modules\" -Recurse          # PS 7

Import-Module VBoxPS
Get-Command -Module VBoxPS
```

VBoxManage wird automatisch gefunden (Installationspfad, `VBOX_MSI_INSTALL_PATH`, `PATH`).
Abweichend: `Set-VBoxManagePath 'D:\Tools\VirtualBox'` oder Umgebungsvariable `VBOXPS_VBOXMANAGE`.

## Schnellstart

```powershell
Get-VBoxVM                                   # alle VMs
Get-VBoxVM -Running | Stop-VBoxVM -Wait      # alle sauber herunterfahren
Start-VBoxVM 'Win11' -WaitForGuestAdditions  # headless starten und warten
New-VBoxSnapshot 'Win11' 'Vor Update'
Restore-VBoxSnapshot 'Win11' 'Vor Update' -Force
```

## Beispiel: Windows 11 komplett automatisiert

```powershell
$cred = Get-Credential labadmin

New-VBoxVM 'Win11-Lab' -OSType Windows11_64 -MemoryMB 8192 -CPUs 4 -DiskSizeGB 80 `
    -Firmware EFI -EnableTpm -EnableSecureBoot

Start-VBoxUnattendedInstall 'Win11-Lab' -IsoPath 'D:\ISO\Win11_24H2.iso' -Credential $cred `
    -Hostname 'win11-lab.lab.local' -Locale de_DE -Country DE `
    -TimeZone 'W. Europe Standard Time' -ImageIndex 6 -InstallGuestAdditions

Wait-VBoxGuestAdditions 'Win11-Lab' -TimeoutSec 3600

Copy-VBoxGuestItem 'Win11-Lab' -Credential $cred -Path .\Scripts\setup.ps1 -Destination 'C:\Deploy'
Invoke-VBoxGuestCommand 'Win11-Lab' -Credential $cred `
    -FilePath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -ArgumentList '-ExecutionPolicy', 'Bypass', '-File', 'C:\Deploy\setup.ps1' -ThrowOnError

Stop-VBoxVM 'Win11-Lab' -Wait
New-VBoxSnapshot 'Win11-Lab' 'Basis'
```

## Beispiel: Linked Clones für ein Lab

```powershell
1..3 | ForEach-Object {
    Copy-VBoxVM 'Win11-Lab' "Client0$_" -Linked -Group 'Lab'
    Set-VBoxVMNetworkAdapter "Client0$_" -Adapter 1 -Type Internal -NetworkName 'LabNet'
}
Get-VBoxVM 'Client*' | Start-VBoxVM
```

## Beispiel: Netzwerk und Storage

```powershell
Add-VBoxNatPortForward 'srv01' -HostPort 2222 -GuestPort 22 -RuleName ssh
Get-VBoxNatPortForward 'srv01'
Set-VBoxVMNetworkAdapter 'srv01' -Adapter 2 -Type Bridged -NetworkName (Get-VBoxBridgedInterface)[0].Name

New-VBoxDisk 'E:\VMs\srv01\data.vdi' -SizeGB 100
Add-VBoxStorageAttachment 'srv01' -ControllerName SATA -Port 2 -Type HDD -Medium 'E:\VMs\srv01\data.vdi'
Mount-VBoxIso 'srv01' additions          # Guest-Additions-ISO einlegen
Get-VBoxGuestIPAddress 'srv01' -Wait
```

## Funktionsübersicht

| Bereich | Funktionen |
|---|---|
| Basis | Get-/Set-VBoxManagePath, Get-VBoxVersion, Invoke-VBoxManage, Get-VBoxHostInfo, Get-VBoxOSType |
| Inventar | Get-VBoxVM, Get-VBoxVMInfo |
| Lifecycle | Start-, Stop-, Suspend-, Resume-, Restart-, Wait-VBoxVM |
| Snapshots | Get-, New-, Restore-, Remove-VBoxSnapshot |
| Maschinen | New-, Copy-, Set-, Remove-VBoxVM, Import-/Export-VBoxAppliance |
| Netzwerk | Get-/Set-VBoxVMNetworkAdapter, Get-/Add-/Remove-VBoxNatPortForward, Get-/New-/Remove-VBoxNatNetwork, Get-/New-/Remove-VBoxHostOnlyInterface, Get-VBoxBridgedInterface |
| Storage | Get-/Add-/Remove-VBoxStorageController, Get-/Add-/Remove-VBoxStorageAttachment, Mount-/Dismount-VBoxIso, Get-/New-/Resize-/Remove-VBoxDisk |
| Gast | Get-VBoxUnattendedIsoInfo, Start-VBoxUnattendedInstall, Wait-VBoxGuestAdditions, Get-VBoxGuestIPAddress, Get-/Set-VBoxGuestProperty, Invoke-VBoxGuestCommand, Copy-VBoxGuestItem, New-VBoxGuestDirectory |

Hilfe zu jeder Funktion: `Get-Help New-VBoxVM -Full` oder die HTML-Referenz `docs/VBoxPS-Referenz.html`.

## Hinweise

- **Warum VBoxManage statt COM-API?** Die COM-API ist versionsgebunden, nur unter Windows verfügbar und
  in PowerShell 7 unzuverlässig. VBoxManage funktioniert überall gleich und ist die offiziell stabile Schnittstelle.
- **Passwörter** werden nie auf der Kommandozeile übergeben, sondern über kurzlebige Temp-Dateien, die
  danach überschrieben und gelöscht werden.
- **Ab VirtualBox 7.0:** TPM/Secure Boot (`New-VBoxVM -EnableTpm/-EnableSecureBoot`), `Stop-VBoxVM -Mode Shutdown`,
  `Restart-VBoxVM -Mode Reboot`. Unattended-Passwortoptionen von 7.1 werden automatisch erkannt.
- **Host-Only-Interfaces** anlegen/löschen braucht unter Windows Administratorrechte. Unter macOS nutzt
  VirtualBox 7 stattdessen Host-Only-Netzwerke (`Invoke-VBoxManage hostonlynet ...`).
- **Guest Control unter Windows:** UAC filtert das Token lokaler Admins. Für administrative Befehle den
  eingebauten Administrator verwenden oder UAC-Remote-Einschränkungen anpassen.
- **Unattended Hostname** muss ein FQDN sein, ohne Punkt hängt das Modul `.local` an.
- Alles, was das Modul nicht abdeckt: `Invoke-VBoxManage <beliebige Argumente>` (mit `-Verbose` sieht man
  bei allen Funktionen den exakten VBoxManage-Aufruf).
