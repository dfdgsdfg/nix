#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Config', 'Apply', 'Id', 'List', 'Address', 'Connect')]
    [string]$Action = 'List',
    [Parameter(Position = 1)]
    [string]$Peer,
    [string]$RustDeskPath
)

$ErrorActionPreference = 'Stop'
$profileDirectory = Join-Path $PSScriptRoot '../home/modules/rustdesk'
$serverProfile = Get-Content (Join-Path $profileDirectory 'profile.json') -Raw | ConvertFrom-Json
$clients = Get-Content (Join-Path $profileDirectory 'clients.json') -Raw | ConvertFrom-Json

function Get-ServerConfig {
    # RustDesk custom_server.rs: reversed URL_SAFE_NO_PAD JSON.
    $json = $serverProfile | ConvertTo-Json -Compress
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $characters = $encoded.ToCharArray()
    [Array]::Reverse($characters)
    return -join $characters
}

function Get-PeerAddress([string]$Id) {
    if ([string]::IsNullOrWhiteSpace($Id) -or $Id -match '[\s@?&#/]') {
        throw 'Provide a bare RustDesk ID or a hostname with an ID in clients.json.'
    }
    return "${Id}@$($serverProfile.host)?key=$($serverProfile.key)"
}

function Find-RustDesk {
    if ($RustDeskPath) {
        if (-not (Test-Path -LiteralPath $RustDeskPath -PathType Leaf)) {
            throw "RustDesk executable not found: $RustDeskPath"
        }
        return (Resolve-Path -LiteralPath $RustDeskPath).Path
    }
    # Prefer the installed service client over a portable Scoop copy.
    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($root) {
            $candidate = Join-Path $root 'RustDesk\rustdesk.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    $command = Get-Command rustdesk.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    throw 'RustDesk is not installed or not on PATH. Supply -RustDeskPath if needed.'
}

function Invoke-RustDesk([string[]]$Arguments) {
    $binary = Find-RustDesk
    # Start-Process waits for Windows GUI executables too. All supplied arguments
    # are a single token (validated IDs or generated base64); only the exe may contain spaces.
    $process = Start-Process -FilePath $binary -ArgumentList $Arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "RustDesk exited with code $($process.ExitCode)" }
}

switch ($Action) {
    'Config' { Get-ServerConfig }
    'List' {
        foreach ($client in $clients.PSObject.Properties) {
            $target = if ($client.Value) { Get-PeerAddress $client.Value } else { 'ID pending' }
            "{0}`t{1}" -f $client.Name, $target
        }
    }
    'Apply' {
        if ($env:OS -ne 'Windows_NT') { throw 'Apply must run on Windows.' }
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Run PowerShell as Administrator, then run this script with Apply again.'
        }
        $service = Get-Service -Name RustDesk -ErrorAction SilentlyContinue
        if (-not $service -or $service.Status -ne 'Running') {
            throw 'Install and start the RustDesk Windows service before applying the server profile.'
        }
        Invoke-RustDesk -Arguments @('--config', (Get-ServerConfig))
        Write-Host 'Config command completed. Verify the server/key in Network settings and Ready in RustDesk.'
    }
    'Id' {
        $binary = Find-RustDesk
        # A pipeline waits and captures console output from the Windows GUI executable.
        $output = & $binary --get-id | Out-String
        if ($LASTEXITCODE -ne 0) { throw "RustDesk exited with code $LASTEXITCODE" }
        $id = $output.Trim()
        if (-not $id -or $id -match '\s') { throw 'No usable ID returned; check the RustDesk service and UI.' }
        Get-PeerAddress $id
    }
    { $_ -in 'Address', 'Connect' } {
        $entry = $clients.PSObject.Properties | Where-Object Name -EQ $Peer | Select-Object -First 1
        $id = if ($entry) { $entry.Value } else { $Peer }
        $target = Get-PeerAddress $id
        if ($Action -eq 'Address') { $target }
        else {
            # Restrict characters because Start-Process serializes arguments on Windows.
            if ($id -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Unsupported characters in RustDesk ID.' }
            Invoke-RustDesk -Arguments @('--connect', $target)
        }
    }
}
