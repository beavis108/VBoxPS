@{
    RootModule           = 'VBoxPS.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '84e79ba0-28fe-4603-b22f-56305a032415'
    Author               = 'Chris'
    Description          = 'Steuerung von Oracle VirtualBox (VM-Lifecycle, Snapshots, Klonen, Netzwerk, Storage, Unattended Install, Guest Control) über VBoxManage.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @(
        'Add-VBoxNatPortForward',
        'Add-VBoxStorageAttachment',
        'Add-VBoxStorageController',
        'Copy-VBoxGuestItem',
        'Copy-VBoxVM',
        'Dismount-VBoxIso',
        'Export-VBoxAppliance',
        'Get-VBoxBridgedInterface',
        'Get-VBoxDisk',
        'Get-VBoxGuestIPAddress',
        'Get-VBoxGuestProperty',
        'Get-VBoxHostInfo',
        'Get-VBoxHostOnlyInterface',
        'Get-VBoxManagePath',
        'Get-VBoxNatNetwork',
        'Get-VBoxNatPortForward',
        'Get-VBoxOSType',
        'Get-VBoxSnapshot',
        'Get-VBoxStorageAttachment',
        'Get-VBoxStorageController',
        'Get-VBoxUnattendedIsoInfo',
        'Get-VBoxVersion',
        'Get-VBoxVM',
        'Get-VBoxVMInfo',
        'Get-VBoxVMNetworkAdapter',
        'Import-VBoxAppliance',
        'Invoke-VBoxGuestCommand',
        'Invoke-VBoxManage',
        'Mount-VBoxIso',
        'New-VBoxDisk',
        'New-VBoxGuestDirectory',
        'New-VBoxHostOnlyInterface',
        'New-VBoxNatNetwork',
        'New-VBoxSnapshot',
        'New-VBoxVM',
        'Remove-VBoxDisk',
        'Remove-VBoxHostOnlyInterface',
        'Remove-VBoxNatNetwork',
        'Remove-VBoxNatPortForward',
        'Remove-VBoxSnapshot',
        'Remove-VBoxStorageAttachment',
        'Remove-VBoxStorageController',
        'Remove-VBoxVM',
        'Resize-VBoxDisk',
        'Restart-VBoxVM',
        'Restore-VBoxSnapshot',
        'Resume-VBoxVM',
        'Set-VBoxGuestProperty',
        'Set-VBoxManagePath',
        'Set-VBoxVM',
        'Set-VBoxVMNetworkAdapter',
        'Start-VBoxUnattendedInstall',
        'Start-VBoxVM',
        'Stop-VBoxVM',
        'Suspend-VBoxVM',
        'Wait-VBoxGuestAdditions',
        'Wait-VBoxVM'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags = @('VirtualBox', 'VBoxManage', 'Virtualization', 'Lab', 'Automation')
        }
    }
}
