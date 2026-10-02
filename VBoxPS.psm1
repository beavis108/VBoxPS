#Requires -Version 5.1
<#
    VBoxPS – PowerShell-Modul zur Steuerung von Oracle VirtualBox über VBoxManage.
    Kompatibel mit Windows PowerShell 5.1 und PowerShell 7+ (Windows, Linux, macOS).
#>

$privateFiles = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$publicFiles  = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)

foreach ($file in ($privateFiles + $publicFiles)) {
    try { . $file.FullName }
    catch { throw "Fehler beim Laden von $($file.FullName): $_" }
}

# Öffentliche Funktionen aus den Public-Dateien ermitteln (per AST, damit nichts doppelt gepflegt werden muss)
$publicFunctions = foreach ($file in $publicFiles) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
    $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
        ForEach-Object { $_.Name }
}

#region Standardanzeige
$displaySets = @{
    'VBoxPS.VM'                = 'Name', 'State', 'OSType', 'MemoryMB', 'CPUs'
    'VBoxPS.Snapshot'          = 'VMName', 'SnapshotName', 'Depth', 'IsCurrent', 'Description'
    'VBoxPS.NetworkAdapter'    = 'VMName', 'Adapter', 'Type', 'AttachedTo', 'MacAddress', 'CableConnected'
    'VBoxPS.NatPortForward'    = 'VMName', 'Adapter', 'RuleName', 'Protocol', 'HostIP', 'HostPort', 'GuestIP', 'GuestPort'
    'VBoxPS.StorageAttachment' = 'VMName', 'ControllerName', 'Port', 'Device', 'Kind', 'Medium'
    'VBoxPS.CommandResult'     = 'ExitCode', 'StdOut', 'StdErr'
}
foreach ($typeName in $displaySets.Keys) {
    Update-TypeData -TypeName $typeName -DefaultDisplayPropertySet $displaySets[$typeName] -Force
}
#endregion

#region Tab-Vervollständigung
$vmNameCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $word = "$wordToComplete".Trim("'", '"')
    try {
        Get-VBoxVMList | Where-Object { $_.Name -like "$word*" } | Sort-Object Name | ForEach-Object {
            $text = if ($_.Name -match '[\s''"$();,{}@&#`]') { "'" + ($_.Name -replace "'", "''") + "'" } else { $_.Name }
            New-Object System.Management.Automation.CompletionResult($text, $_.Name, 'ParameterValue', $_.UUID)
        }
    }
    catch { }
}
$osTypeCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $word = "$wordToComplete".Trim("'", '"')
    try {
        Get-VBoxOSType | Where-Object { $_.ID -like "$word*" } | ForEach-Object {
            New-Object System.Management.Automation.CompletionResult($_.ID, $_.ID, 'ParameterValue', $_.Description)
        }
    }
    catch { }
}

$vmCommands = foreach ($fn in $publicFunctions) {
    $cmd = $ExecutionContext.InvokeCommand.GetCommand($fn, 'Function')
    if ($cmd -and $cmd.Parameters.ContainsKey('Name') -and $cmd.Parameters['Name'].Aliases -contains 'VMName') { $fn }
}
if ($vmCommands) { Register-ArgumentCompleter -CommandName $vmCommands -ParameterName 'Name' -ScriptBlock $vmNameCompleter }
Register-ArgumentCompleter -CommandName 'New-VBoxVM', 'Set-VBoxVM' -ParameterName 'OSType' -ScriptBlock $osTypeCompleter
#endregion

Export-ModuleMember -Function $publicFunctions
