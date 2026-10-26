param(
    [Parameter(Mandatory = $true)][string]$Token,
    [string]$Repo = "athena-explorer",
    [string]$Description = "Studio-style Roblox explorer + offline MCP connector"
)

$ErrorActionPreference = "Stop"
$git = "C:\Users\bob\Documents\tools\mingit\cmd\git.exe"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$headers = @{
    Authorization        = "Bearer $Token"
    Accept               = "application/vnd.github+json"
    "User-Agent"         = "athena-explorer"
    "X-GitHub-Api-Version" = "2022-11-28"
}

Write-Host "asking GitHub who we are..."
$me = Invoke-RestMethod "https://api.github.com/user" -Headers $headers -TimeoutSec 60
$login = $me.login
Write-Host "logged in as $login"

$exists = $true
try {
    Invoke-RestMethod "https://api.github.com/repos/$login/$Repo" -Headers $headers -TimeoutSec 60 | Out-Null
} catch {
    $exists = $false
}

if (-not $exists) {
    Write-Host "creating $login/$Repo ..."
    $body = @{ name = $Repo; description = $Description; private = $false } | ConvertTo-Json
    Invoke-RestMethod "https://api.github.com/user/repos" -Method Post -Headers $headers -Body $body -ContentType "application/json" -TimeoutSec 60 | Out-Null
    Start-Sleep -Seconds 2
} else {
    Write-Host "$login/$Repo already exists"
}

Push-Location $root
try {
    & $git remote remove origin 2>$null
    & $git remote add origin "https://x-access-token:$Token@github.com/$login/$Repo.git"
    & $git add -A
    & $git -c user.name="bob" -c user.email="bob@localhost" commit -m "Update Athena Explorer" 2>$null
    & $git branch -M main
    & $git push -u origin main
    if ($LASTEXITCODE -ne 0) { throw "git push failed" }
    & $git remote set-url origin "https://github.com/$login/$Repo.git"
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "done. raw link:"
Write-Host "  https://raw.githubusercontent.com/$login/$Repo/main/Athena.lua"
Write-Host ""
Write-Host "paste this in the executor:"
Write-Host "  loadstring(game:HttpGet(`"https://raw.githubusercontent.com/$login/$Repo/main/Athena.lua`"))()"
