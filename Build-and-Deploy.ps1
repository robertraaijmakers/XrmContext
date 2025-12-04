#!/usr/bin/env pwsh
# Build and Deploy XrmContext for .NET 8
# This script builds the XrmContext project and copies the output to the files/XrmContext folder

param(
    [string]$Configuration = "Release",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

# Paths
$ProjectRoot = $PSScriptRoot
$ProjectFile = Join-Path $ProjectRoot "src/XrmContext/XrmContext.fsproj"
$OutputFolder = Join-Path $ProjectRoot "files/XrmContext"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "XrmContext Build & Deploy (.NET 8)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Clean output folder
if (Test-Path $OutputFolder) {
    Write-Host "Cleaning output folder: $OutputFolder" -ForegroundColor Yellow
    Remove-Item -Path $OutputFolder -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

if (-not $SkipBuild) {
    # Build the project
    Write-Host "`nBuilding XrmContext ($Configuration)..." -ForegroundColor Green
    Write-Host "Project: $ProjectFile`n" -ForegroundColor Gray
    
    dotnet build $ProjectFile -c $Configuration
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    
    Write-Host "`n✓ Build completed successfully" -ForegroundColor Green
}

# Publish the project
Write-Host "`nPublishing XrmContext..." -ForegroundColor Green
$PublishPath = Join-Path $ProjectRoot "src/XrmContext/bin/$Configuration/net8.0/publish"

dotnet publish $ProjectFile -c $Configuration -o $PublishPath --no-build

if ($LASTEXITCODE -ne 0) {
    Write-Error "Publish failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

# Copy published files to output folder
Write-Host "Copying files to: $OutputFolder" -ForegroundColor Green
Copy-Item -Path "$PublishPath/*" -Destination $OutputFolder -Recurse -Force

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✓ Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nXrmContext.dll location:" -ForegroundColor Gray
Write-Host "  $OutputFolder/XrmContext.dll`n" -ForegroundColor White

# Verify the DLL exists
$DllPath = Join-Path $OutputFolder "XrmContext.dll"
if (Test-Path $DllPath) {
    Write-Host "✓ XrmContext.dll verified" -ForegroundColor Green
    
    # Test that it runs
    Write-Host "`nTesting XrmContext execution..." -ForegroundColor Yellow
    $testOutput = & dotnet $DllPath --help 2>&1
    if ($LASTEXITCODE -eq 0 -or $testOutput -match "Usage") {
        Write-Host "✓ XrmContext is executable" -ForegroundColor Green
    }
    else {
        Write-Warning "Could not verify XrmContext execution"
    }
}
else {
    Write-Error "XrmContext.dll not found after deployment!"
    exit 1
}

Write-Host "`nYou can now run:" -ForegroundColor Cyan
Write-Host "  cd files" -ForegroundColor White
Write-Host "  ./XrmContext.ps1 -Environment Dev" -ForegroundColor White
Write-Host ""
