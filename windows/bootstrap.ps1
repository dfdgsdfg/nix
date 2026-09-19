#Requires -Version 5.1
<#
.SYNOPSIS
    Bring a Windows host up to the state this repo declares.

.DESCRIPTION
    Nix cannot reach the Windows side of a WSL host, so this script covers the
    gap: package managers install what packages/*.json declares, chezmoi renders
    the dotfiles under windows/chezmoi, and secrets stay in the repo's existing
    SOPS files rather than being copied in a second encrypted format.

    Every step is guarded, so re-running only fills in what is missing.

    Private keys are deliberately NOT written to disk. The SSH key is loaded
    straight into the Windows ssh-agent, which keeps it encrypted under DPAPI in
    the registry. See -SkipSshAgent and README.md for the reasoning.

.PARAMETER RepoRoot
    Checkout of this repository. Defaults to the parent of this script.

.PARAMETER SkipPackages
    Leave winget and scoop alone. Useful when only dotfiles changed.

.PARAMETER SkipSshAgent
    Do not touch the ssh-agent service or load any key.

.EXAMPLE
    pwsh -File windows\bootstrap.ps1

.EXAMPLE
    # ssh-agent setup needs an elevated shell; everything else does not.
    Start-Process pwsh -Verb RunAs -ArgumentList '-File','windows\bootstrap.ps1'
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$SkipPackages,
    [switch]$SkipSshAgent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Failures = @()

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Skip { param([string]$Message) Write-Host "    skip: $Message" -ForegroundColor DarkGray }
function Write-Done { param([string]$Message) Write-Host "    ok:   $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "    warn: $Message" -ForegroundColor Yellow }

function Add-Failure {
    param([string]$Step, [string]$Message)
    $script:Failures += [pscustomobject]@{ Step = $Step; Message = $Message }
    Write-Host "    FAIL: $Message" -ForegroundColor Red
}

function Test-Command {
    param([string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-RealPython {
    # The Store alias is a zero-byte stub: it resolves in PATH, prints nothing
    # useful, and never reports a version. A real interpreter answers.
    if (-not (Test-Command 'python')) { return $false }
    try {
        $version = (& python -c 'import sys; print(sys.version_info[0])' 2>$null | Out-String).Trim()
        return $version -match '^\d+$'
    } catch {
        return $false
    }
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

$PackagesDir = Join-Path $PSScriptRoot 'packages'
$ChezmoiSource = Join-Path $PSScriptRoot 'chezmoi'

Write-Host ""
Write-Host "Windows bootstrap" -ForegroundColor White
Write-Host "  repo:   $RepoRoot"
Write-Host "  source: $ChezmoiSource"
Write-Host ""

# ---------------------------------------------------------------- packages ---

if (-not $SkipPackages) {
    Write-Step 'winget packages'
    if (Test-Command 'winget') {
        $manifest = Join-Path $PackagesDir 'winget.json'
        if (Test-Path $manifest) {
            # import exits non-zero when a package is already current, which is
            # the normal case on re-runs, so judge the outcome by output alone.
            $output = & winget import --import-file $manifest `
                --accept-package-agreements --accept-source-agreements `
                --disable-interactivity --ignore-versions 2>&1
            $text = $output -join "`n"
            if ($text -match 'Installer failed|Failed to install') {
                Add-Failure 'winget' "some packages failed; run manually: winget import --import-file $manifest"
            } else {
                Write-Done 'winget manifest applied'
            }
        } else {
            Add-Failure 'winget' "manifest missing: $manifest"
        }
    } else {
        Add-Failure 'winget' 'winget not found; install App Installer from the Microsoft Store'
    }

    Write-Step 'scoop'
    if (-not (Test-Command 'scoop')) {
        Write-Warn 'scoop not installed; installing for the current user'
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
            Write-Done 'scoop installed'
        } catch {
            Add-Failure 'scoop' "install failed: $($_.Exception.Message)"
        }
    } else {
        Write-Skip 'scoop already installed'
    }

    if (Test-Command 'scoop') {
        $manifest = Join-Path $PackagesDir 'scoop.json'
        if (Test-Path $manifest) {
            try {
                & scoop import $manifest
                Write-Done 'scoop manifest applied'
            } catch {
                Add-Failure 'scoop' "import failed: $($_.Exception.Message)"
            }
        } else {
            Add-Failure 'scoop' "manifest missing: $manifest"
        }
    }
} else {
    Write-Step 'packages'
    Write-Skip '-SkipPackages was passed'
}

# ------------------------------------------------------------------- tools ---

Write-Step 'sops, chezmoi, python'
foreach ($tool in @('sops', 'chezmoi', 'age', 'python')) {
    # Windows ships a zero-byte python.exe App Execution Alias that only opens
    # the Store, and it sits in PATH, so presence alone proves nothing. Ask the
    # interpreter to identify itself instead.
    $present = if ($tool -eq 'python') { Test-RealPython } else { Test-Command $tool }
    if ($present) {
        Write-Skip "$tool already installed"
        continue
    }
    if (-not (Test-Command 'scoop')) {
        Add-Failure $tool 'scoop unavailable, cannot install'
        continue
    }
    try {
        & scoop install $tool
        Write-Done "$tool installed"
    } catch {
        Add-Failure $tool "install failed: $($_.Exception.Message)"
    }
}

if (-not (Test-RealPython)) {
    Add-Failure 'python' 'no working interpreter; the chezmoi modify_ scripts cannot run without one'
    Write-Host @"
    If scoop installed python but this still fails, the Store alias is winning
    in PATH. Turn it off under
    Settings > Apps > Advanced app settings > App execution aliases.
"@ -ForegroundColor DarkGray
}

# --------------------------------------------------------------- age identity ---

Write-Step 'SOPS age identity'
$AgeKeyFile = Join-Path $env:USERPROFILE '.config\sops\age\keys.txt'
if (Test-Path $AgeKeyFile) {
    Write-Skip "identity present at $AgeKeyFile"
} else {
    Write-Warn "no age identity at $AgeKeyFile"
    Write-Host @"
    Copy it from a host that already has it, over a channel you trust:

      wsl.exe -d NixOS -- cat ~/.config/sops/age/keys.txt

    Save that to the path above, then re-run this script. Nothing below this
    point can decrypt without it.
"@ -ForegroundColor DarkGray
}
$env:SOPS_AGE_KEY_FILE = $AgeKeyFile

# ----------------------------------------------------------------- ssh key ---

if (-not $SkipSshAgent) {
    Write-Step 'ssh-agent'
    $service = Get-Service ssh-agent -ErrorAction SilentlyContinue
    if (-not $service) {
        Add-Failure 'ssh-agent' 'service not found; install the OpenSSH Client optional feature'
    } elseif (-not (Test-Admin)) {
        Write-Warn 'ssh-agent is not running and enabling it needs an elevated shell'
        Write-Host @"
    Run once from an Administrator PowerShell:

      Set-Service ssh-agent -StartupType Automatic
      Start-Service ssh-agent

    Then re-run this script (no elevation needed) to load the key.
"@ -ForegroundColor DarkGray
    } else {
        if ($service.StartType -eq 'Disabled') {
            Set-Service ssh-agent -StartupType Automatic
            Write-Done 'ssh-agent set to start automatically'
        }
        if ($service.Status -ne 'Running') {
            Start-Service ssh-agent
            Write-Done 'ssh-agent started'
        } else {
            Write-Skip 'ssh-agent already running'
        }
    }

    if ((Get-Service ssh-agent -ErrorAction SilentlyContinue).Status -eq 'Running') {
        if (-not (Test-Path $AgeKeyFile)) {
            Write-Skip 'no age identity yet, cannot decrypt the key'
        } elseif (-not (Test-Command 'sops')) {
            Write-Skip 'sops unavailable, cannot decrypt the key'
        } else {
            # Compare fingerprints so a re-run does not stack duplicate identities.
            $loaded = (& ssh-add -l 2>&1) -join "`n"
            $sshSecrets = Join-Path $RepoRoot 'secrets\ssh.yaml'
            $pub = & sops -d --extract '["ssh"]["id_ed25519_pub"]' $sshSecrets 2>$null
            $want = if ($pub) { ($pub -split '\s+')[1] } else { $null }

            if ($want -and $loaded -match [regex]::Escape($want)) {
                Write-Skip 'key already loaded in the agent'
            } else {
                # ssh-add insists on a file, so stage one in the per-user temp
                # directory and remove it in finally -- it must not outlive this.
                $staged = Join-Path $env:TEMP ("id_ed25519_" + [guid]::NewGuid().ToString('N'))
                try {
                    & sops -d --extract '["ssh"]["id_ed25519"]' $sshSecrets |
                        Set-Content -Path $staged -NoNewline -Encoding ascii
                    # ssh-add rejects a key any other account can read.
                    & icacls $staged /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
                    & ssh-add $staged
                    if ($LASTEXITCODE -eq 0) {
                        Write-Done 'key loaded into ssh-agent (DPAPI-backed, no file on disk)'
                    } else {
                        Add-Failure 'ssh-add' "exit code $LASTEXITCODE"
                    }
                } catch {
                    Add-Failure 'ssh-add' $_.Exception.Message
                } finally {
                    if (Test-Path $staged) { Remove-Item $staged -Force }
                }
            }
        }
    }
} else {
    Write-Step 'ssh-agent'
    Write-Skip '-SkipSshAgent was passed'
}

# ----------------------------------------------------------------- chezmoi ---

Write-Step 'chezmoi'
if (-not (Test-Command 'chezmoi')) {
    Add-Failure 'chezmoi' 'not installed, cannot apply dotfiles'
} elseif (-not (Test-Path $ChezmoiSource)) {
    Add-Failure 'chezmoi' "source directory missing: $ChezmoiSource"
} else {
    try {
        # --source keeps the state in this repo instead of chezmoi's own clone,
        # so the nix tree stays the single checkout to update.
        & chezmoi init --source $ChezmoiSource
        & chezmoi apply --source $ChezmoiSource
        Write-Done 'dotfiles applied'
    } catch {
        Add-Failure 'chezmoi' $_.Exception.Message
    }
}

# ----------------------------------------------------------------- summary ---

Write-Host ""
if ($script:Failures.Count -eq 0) {
    Write-Host "Bootstrap finished with no failures." -ForegroundColor Green
    exit 0
}

Write-Host "Bootstrap finished with $($script:Failures.Count) failure(s):" -ForegroundColor Red
$script:Failures | ForEach-Object { Write-Host "  [$($_.Step)] $($_.Message)" -ForegroundColor Red }
exit 1
