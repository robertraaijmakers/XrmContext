#!/usr/bin/env pwsh
# Test XrmContext Execution
# Quick test to verify XrmContext can run with the current configuration

param(
    [string]$Environment = "Dev"
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "XrmContext Configuration Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if config file exists
$ConfigFile = Join-Path $PSScriptRoot "files/_Config.ps1"
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Configuration file not found: $ConfigFile"
    exit 1
}

# Load config
Write-Host "Loading configuration..." -ForegroundColor Yellow
$config = & $ConfigFile
$envConfig = $config.Environments.$Environment

if (-not $envConfig) {
    Write-Error "Environment '$Environment' not found in configuration"
    Write-Host "Available environments: $($config.Environments.Keys -join ', ')" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Configuration loaded" -ForegroundColor Green
Write-Host "`nEnvironment: $Environment" -ForegroundColor Cyan
Write-Host "  Name: $($envConfig.name)" -ForegroundColor Gray
Write-Host "  URL: $($envConfig.url)" -ForegroundColor Gray
Write-Host "  Auth Type: $($envConfig.authType)" -ForegroundColor Gray

# Check DLL exists
$DllPath = Join-Path $PSScriptRoot "files/XrmContext/XrmContext.dll"
if (-not (Test-Path $DllPath)) {
    Write-Host "`n❌ XrmContext.dll not found!" -ForegroundColor Red
    Write-Host "   Expected: $DllPath" -ForegroundColor Yellow
    Write-Host "`nPlease run the build script:" -ForegroundColor Yellow
    Write-Host "   ./Build-and-Deploy.ps1" -ForegroundColor White
    exit 1
}

Write-Host "`n✓ XrmContext.dll found" -ForegroundColor Green

# Test execution
Write-Host "`nTesting XrmContext execution..." -ForegroundColor Yellow
$testOutput = & dotnet $DllPath --help 2>&1

if ($LASTEXITCODE -eq 0 -or $testOutput -match "Usage") {
    Write-Host "✓ XrmContext is executable" -ForegroundColor Green
    Write-Host "`nUsage information:" -ForegroundColor Cyan
    $testOutput | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
}
else {
    Write-Warning "Could not verify XrmContext execution"
    Write-Host $testOutput -ForegroundColor Red
}

# Validate authentication configuration
Write-Host "`nValidating authentication configuration..." -ForegroundColor Yellow

$issues = @()

switch ($envConfig.authType) {
    "OAuth" {
        if (-not $envConfig.url) { $issues += "Missing 'url'" }
        if (-not $envConfig.username) { $issues += "Missing 'username' (required for OAuth)" }
        if (-not $envConfig.password) { $issues += "Missing 'password' (required for OAuth)" }
        Write-Host "  Auth Method: OAuth (Username/Password)" -ForegroundColor Gray
    }
    "ClientSecret" {
        if (-not $envConfig.url) { $issues += "Missing 'url'" }
        if (-not $envConfig.clientId) { $issues += "Missing 'clientId' (required for ClientSecret)" }
        if (-not $envConfig.clientSecret) { $issues += "Missing 'clientSecret' (required for ClientSecret)" }
        Write-Host "  Auth Method: Client Secret (Service Principal)" -ForegroundColor Gray
    }
    "ConnectionString" {
        if (-not $envConfig.connectionString) { $issues += "Missing 'connectionString'" }
        Write-Host "  Auth Method: Connection String" -ForegroundColor Gray
    }
    default {
        $issues += "Unknown authType: $($envConfig.authType)"
    }
}

if ($issues.Count -gt 0) {
    Write-Host "`n⚠️  Configuration Issues:" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
    Write-Host "`nPlease update files/_Config.ps1" -ForegroundColor Cyan
}
else {
    Write-Host "✓ Authentication configuration valid" -ForegroundColor Green
}

# Check plugin configuration
if ($config.Plugins -and $config.Plugins.entities) {
    Write-Host "`n✓ Plugin configuration found" -ForegroundColor Green
    Write-Host "  Entities: $($config.Plugins.entities.Count)" -ForegroundColor Gray
    Write-Host "  Namespace: $($config.Plugins.entityNamespace)" -ForegroundColor Gray
}
else {
    Write-Host "`n⚠️  No plugin entities configured" -ForegroundColor Yellow
}

# Check output path
if ($config.Path -and $config.Path.entityFolder) {
    $outputPath = $config.Path.entityFolder
    Write-Host "`n✓ Output path configured" -ForegroundColor Green
    Write-Host "  Path: $outputPath" -ForegroundColor Gray
    
    if (-not (Test-Path $outputPath)) {
        Write-Host "  ℹ️  Path doesn't exist yet (will be created)" -ForegroundColor Cyan
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
if ($issues.Count -eq 0) {
    Write-Host "✓ Ready to Run!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "Execute with:" -ForegroundColor Cyan
    Write-Host "  cd files" -ForegroundColor White
    Write-Host "  ./XrmContext.ps1 -Environment $Environment" -ForegroundColor White
}
else {
    Write-Host "⚠️  Configuration Needs Attention" -ForegroundColor Yellow
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "Please fix the issues above in:" -ForegroundColor Yellow
    Write-Host "  $ConfigFile" -ForegroundColor White
}
Write-Host ""
