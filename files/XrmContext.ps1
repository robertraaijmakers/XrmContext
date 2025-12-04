param(
    [string]$Environment = "Dev",
    [string]$ConfigFile = "$PSScriptRoot/_Config.ps1",
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$XdtArguments
)

# Enable verbose output
$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Continue'

# Set the path to your XrmDefinitelyTyped folder
$XdtPath = "$PSScriptRoot/XrmContext"
$DllPath = Join-Path $XdtPath "XrmContext.dll"

# Create logs directory if it doesn't exist
$LogDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# Create log file with timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path $LogDir "xdt_$timestamp.log"
$ErrorLogFile = Join-Path $LogDir "xdt_$timestamp.error.log"

# Check if DLL exists
if (-not (Test-Path $DllPath)) {
    Write-Error "XrmContext.dll not found at: $DllPath"
    Write-Host "Please ensure the published files are in: $XdtPath"
    exit 1
}

# Load configuration from _Config.ps1
Write-Verbose "Loading configuration from: $ConfigFile"
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Configuration file not found: $ConfigFile"
    Write-Host "Please ensure _Config.ps1 exists in the script directory."
    exit 1
}

$config = & $ConfigFile
$envConfig = $config.Environments.$Environment

if (-not $envConfig) {
    Write-Error "Environment '$Environment' not found in configuration file."
    Write-Host "Available environments: $($config.Environments.Keys -join ', ')"
    exit 1
}

# Build command-line arguments from config
$configArgs = @()

# Add URL (required)
$configArgs += "/url:$($envConfig.url)"

# Add authentication method
if ($envConfig.authType) {
    $configArgs += "/method:$($envConfig.authType)"
}

# Add authentication parameters based on type
switch ($envConfig.authType) {
    "OAuth" {
        if ($envConfig.username) {
            $configArgs += "/username:$($envConfig.username)"
        }
        # Password is optional - if empty, will use interactive browser login
        if ($envConfig.password) {
            $configArgs += "/password:$($envConfig.password)"
        }
        if ($envConfig.appId) {
            $configArgs += "/mfaAppId:$($envConfig.appId)"
        }
        # Add redirect URL for interactive OAuth
        if ($envConfig.redirectUri) {
            $configArgs += "/mfaReturnUrl:$($envConfig.redirectUri)"
        }
        elseif (-not $envConfig.password) {
            # Default to localhost loopback for interactive login
            $configArgs += "/mfaReturnUrl:http://localhost:8080"
        }
    }
    "ClientSecret" {
        if ($envConfig.clientId) {
            $configArgs += "/mfaAppId:$($envConfig.clientId)"
        }
        if ($envConfig.clientSecret) {
            $configArgs += "/mfaClientSecret:$($envConfig.clientSecret)"
        }
    }
    "ConnectionString" {
        if ($envConfig.connectionString) {
            $configArgs += "/connectionString:$($envConfig.connectionString)"
        }
    }
}

# Add plugin/entity configuration from config
if ($config.Plugins -and $config.Plugins.entities) {
    $entityList = $config.Plugins.entities -join ','
    $configArgs += "/entities:$entityList"
}

# Add output path
if ($config.Path -and $config.Path.entityFolder) {
    # Normalize path separators for cross-platform compatibility
    $outputPath = $config.Path.entityFolder -replace '\\', '/'
    $configArgs += "/out:$outputPath"
}

# Add namespace
if ($config.Plugins -and $config.Plugins.entityNamespace) {
    $configArgs += "/namespace:$($config.Plugins.entityNamespace)"
}

# Add any additional arguments passed to the script
if ($XdtArguments) {
    $configArgs += $XdtArguments
}

# Validate authentication requirements
if ($envConfig.authType -eq "OAuth") {
    if (-not $envConfig.username) {
        Write-Host "`n❌ OAuth authentication requires a username" -ForegroundColor Red
        Write-Host "`nPlease update your configuration in: $ConfigFile" -ForegroundColor Yellow
        exit 1
    }
    
    if (-not $envConfig.password) {
        Write-Host "`n🔐 Interactive OAuth Mode" -ForegroundColor Cyan
        Write-Host "No password provided - will use browser-based authentication" -ForegroundColor Yellow
        Write-Host "A browser window will open for you to sign in." -ForegroundColor Gray
    }
}

if ($envConfig.authType -eq "ClientSecret" -and (-not $envConfig.clientId -or -not $envConfig.clientSecret)) {
    Write-Host "`n❌ ClientSecret authentication requires clientId and clientSecret" -ForegroundColor Red
    Write-Host "`nPlease update your configuration in: $ConfigFile" -ForegroundColor Yellow
    exit 1
}

# Display the command being executed
Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "XrmContext Code Generation" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Green
Write-Host "URL: $($envConfig.url)" -ForegroundColor Gray
Write-Host "Auth Type: $($envConfig.authType)" -ForegroundColor Gray
Write-Host "`nExecuting: dotnet $DllPath $($configArgs -join ' ')" -ForegroundColor Yellow
Write-Host "======================================`n" -ForegroundColor Cyan

# Execute XrmContext
try {
    # Combine DllPath and configArgs into a single array
    $allArgs = @($DllPath) + $configArgs
    
    $process = Start-Process -FilePath "dotnet" `
        -ArgumentList $allArgs `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $LogFile `
        -RedirectStandardError $ErrorLogFile

    # Display output
    Write-Host "`nOutput Log:" -ForegroundColor Cyan
    Get-Content $LogFile | ForEach-Object { Write-Host $_ }

    if ($process.ExitCode -ne 0) {
        Write-Host "`nErrors occurred:" -ForegroundColor Red
        Get-Content $ErrorLogFile | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        Write-Host "`nXrmContext failed with exit code: $($process.ExitCode)" -ForegroundColor Red
        exit $process.ExitCode
    }
    else {
        Write-Host "`n✓ XrmContext completed successfully!" -ForegroundColor Green
        Write-Host "  Output: $($config.Path.entityFolder)" -ForegroundColor Gray
        Write-Host "  Log: $LogFile" -ForegroundColor Gray
    }
}
catch {
    Write-Error "Failed to execute XrmContext: $_"
    if (Test-Path $ErrorLogFile) {
        Write-Host "`nError details:" -ForegroundColor Red
        Get-Content $ErrorLogFile | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }
    exit 1
}