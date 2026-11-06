# SPDX-License-Identifier: Apache-2.0
<#
.SYNOPSIS
  Creates the local RAKIA development database and writes .env.

.DESCRIPTION
  Connects to a local PostgreSQL as a superuser (password asked at a hidden
  prompt, or taken from PGPASSWORD if already set in this shell), then:
    1. generates strong random passwords for rakia_migrator and rakia_api;
    2. creates or repairs both roles, the `rakia` database and schema
       (db/bootstrap/bootstrap.sql);
    3. signs in as each role and checks its privileges (verify.sql);
    4. writes .env at the repository root from .env.example, readable only
       by you.
  Nothing secret is printed. An existing .env is never overwritten.
  Running it again (after moving .env away) gives both roles new passwords.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File db\bootstrap\bootstrap-local.ps1
#>
[CmdletBinding()]
param(
  [string]$SuperUser = 'postgres',
  [string]$DbHost = 'localhost',
  [ValidateRange(1, 65535)][int]$Port = 5432,
  [string]$EnvFile,
  [string]$Psql
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $EnvFile) { $EnvFile = Join-Path $root '.env' }
$example = Join-Path $root '.env.example'

if (Test-Path -LiteralPath $EnvFile) {
  throw "$EnvFile already exists and is never overwritten. Move it away first if you want new credentials."
}

if (-not $Psql) {
  $cmd = Get-Command psql -ErrorAction SilentlyContinue
  if ($cmd) {
    $Psql = $cmd.Source
  } else {
    $Psql = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' -ErrorAction SilentlyContinue |
      Sort-Object { [int]$_.Directory.Parent.Name } -Descending |
      Select-Object -First 1 -ExpandProperty FullName
  }
}
if (-not $Psql -or -not (Test-Path -LiteralPath $Psql)) {
  throw 'psql was not found. Add PostgreSQL''s bin directory to PATH or pass -Psql <path to psql.exe>.'
}

function Get-RandomSecret {
  # 32 characters from [A-Za-z0-9] (about 190 bits), by rejection sampling
  # so every character is equally likely.
  $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $chars = New-Object System.Collections.Generic.List[char]
    $buf = New-Object byte[] 64
    while ($chars.Count -lt 32) {
      $rng.GetBytes($buf)
      foreach ($b in $buf) {
        if ($b -lt 248 -and $chars.Count -lt 32) { $chars.Add($alphabet[$b % 62]) }
      }
    }
    return -join $chars
  } finally {
    $rng.Dispose()
  }
}

function ConvertTo-Credential {
  param(
    [Parameter(Mandatory)][string]$User,
    [Parameter(Mandatory)][string]$Secret
  )
  $secure = New-Object System.Security.SecureString
  foreach ($c in $Secret.ToCharArray()) { $secure.AppendChar($c) }
  $secure.MakeReadOnly()
  return New-Object System.Management.Automation.PSCredential($User, $secure)
}

function Invoke-Psql {
  param(
    [Parameter(Mandatory)][System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory)][string]$Database,
    [string]$File,
    [string]$Stdin
  )
  $user = $Credential.UserName
  $psqlArgs = @('-X', '-q', '-v', 'ON_ERROR_STOP=1', '-h', $DbHost, '-p', "$Port",
    '-U', $user, '-d', $Database, '-w')
  if ($File) { $psqlArgs += @('-t', '-A', '-f', $File) }
  # The password reaches psql through its environment only, for this call.
  $env:PGPASSWORD = $Credential.GetNetworkCredential().Password
  try {
    if ($Stdin) {
      $out = $Stdin | & $Psql @psqlArgs
    } else {
      $out = & $Psql @psqlArgs
    }
    if ($LASTEXITCODE -ne 0) { throw "psql failed as $user (exit $LASTEXITCODE)." }
    return $out
  } finally {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  }
}

if ($env:PGPASSWORD) {
  $super = ConvertTo-Credential -User $SuperUser -Secret $env:PGPASSWORD
} else {
  $prompt = "Password for PostgreSQL superuser '$SuperUser' on ${DbHost}:$Port"
  $super = New-Object System.Management.Automation.PSCredential(
    $SuperUser, (Read-Host -AsSecureString $prompt))
}

$migratorSecret = Get-RandomSecret
$apiSecret = Get-RandomSecret
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)

$bootstrap = (Join-Path $PSScriptRoot 'bootstrap.sql') -replace '\\', '/'
$verify = Join-Path $PSScriptRoot 'verify.sql'

Write-Host "Creating roles and database on ${DbHost}:$Port ..."
$script = "\set migrator_password '$migratorSecret'`n\set api_password '$apiSecret'`n\i '$bootstrap'`n"
Invoke-Psql -Credential $super -Database postgres -Stdin $script | Out-Null
$super = $null

Write-Host 'Checking both roles ...'
Invoke-Psql -Credential (ConvertTo-Credential -User rakia_migrator -Secret $migratorSecret) `
  -Database rakia -File $verify | Write-Host
Invoke-Psql -Credential (ConvertTo-Credential -User rakia_api -Secret $apiSecret) `
  -Database rakia -File $verify | Write-Host

$values = @{
  'RAKIA_DB_HOST'              = $DbHost
  'RAKIA_DB_PORT'              = "$Port"
  'RAKIA_DB_NAME'              = 'rakia'
  'RAKIA_DB_USER'              = 'rakia_api'
  'RAKIA_DB_PASSWORD'          = $apiSecret
  'RAKIA_DB_MIGRATOR_USER'     = 'rakia_migrator'
  'RAKIA_DB_MIGRATOR_PASSWORD' = $migratorSecret
}
$lines = foreach ($line in Get-Content -LiteralPath $example -Encoding UTF8) {
  if ($line -match '^([A-Z0-9_]+)=' -and $values.ContainsKey($Matches[1])) {
    "$($Matches[1])=$($values[$Matches[1]])"
  } else {
    $line
  }
}

# Create the file empty, restrict it to the current user, then fill it.
[System.IO.File]::WriteAllText($EnvFile, '')
$me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls.exe $EnvFile /inheritance:r /grant:r "${me}:(R,W)" | Out-Null
if ($LASTEXITCODE -ne 0) {
  Remove-Item -LiteralPath $EnvFile
  throw "Could not restrict access to $EnvFile; nothing was written."
}
[System.IO.File]::WriteAllText($EnvFile, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
$migratorSecret = $null
$apiSecret = $null

Write-Host "Wrote $EnvFile (readable only by $me). Passwords were not displayed."
