Write-Host "Salesforce LWC Google Sheets Integration Installer" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Check for SFDX CLI
Write-Host "`nChecking for Salesforce CLI..." -ForegroundColor Yellow
$sfdxInstalled = Get-Command sfdx -ErrorAction SilentlyContinue
if (-not $sfdxInstalled) {
    Write-Host "Salesforce CLI not found. Please install it from:" -ForegroundColor Red
    Write-Host "https://developer.salesforce.com/tools/sfdxcli" -ForegroundColor Cyan
    exit 1
}

# Function to prompt for input with validation
function Get-ValidatedInput {
    param (
        [string]$prompt,
        [string]$validationPattern,
        [string]$errorMessage
    )
    do {
        $input = Read-Host -Prompt $prompt
        if ($input -match $validationPattern) {
            return $input
        }
        Write-Host $errorMessage -ForegroundColor Red
    } while ($true)
}

# Collect information
Write-Host "`nPlease provide the following information:" -ForegroundColor Yellow

# Get Salesforce Org Username
$sfUsername = Get-ValidatedInput -prompt "Enter your Salesforce username" -validationPattern ".+@.+" -errorMessage "Please enter a valid email address"

# Get Google Cloud Project details
Write-Host "`nGoogle Cloud Project Setup:" -ForegroundColor Yellow
$googleClientId = Get-ValidatedInput -prompt "Enter your Google Cloud Project Client ID" -validationPattern ".+" -errorMessage "Client ID cannot be empty"
$googleClientSecret = Get-ValidatedInput -prompt "Enter your Google Cloud Project Client Secret" -validationPattern ".+" -errorMessage "Client Secret cannot be empty"

# Create temporary files for deployment
$tempDir = Join-Path $PSScriptRoot "temp_deploy"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Create Named Credentials metadata
$namedCredentialPath = Join-Path $tempDir "namedCredentials"
New-Item -ItemType Directory -Force -Path $namedCredentialPath | Out-Null

$namedCredentialContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>GoogleSheets</label>
    <endpoint>https://sheets.googleapis.com</endpoint>
    <principalType>NamedUser</principalType>
    <protocol>OAuth</protocol>
    <authProvider>GoogleSheets</authProvider>
</NamedCredential>
"@

$authProviderContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<AuthProvider xmlns="http://soap.sforce.com/2006/04/metadata">
    <friendlyName>Google Sheets API</friendlyName>
    <includeOrgIdInIdentifier>false</includeOrgIdInIdentifier>
    <providerType>Google</providerType>
    <consumerKey>$googleClientId</consumerKey>
    <consumerSecret>$googleClientSecret</consumerSecret>
    <defaultScopes>https://www.googleapis.com/auth/spreadsheets</defaultScopes>
</AuthProvider>
"@

Set-Content -Path (Join-Path $namedCredentialPath "GoogleSheets.namedCredential-meta.xml") -Value $namedCredentialContent
Set-Content -Path (Join-Path $tempDir "GoogleSheets.authprovider-meta.xml") -Value $authProviderContent

# Deploy to Salesforce
Write-Host "`nDeploying components to Salesforce..." -ForegroundColor Yellow

# Authenticate with Salesforce
Write-Host "Authenticating with Salesforce..." -ForegroundColor Yellow
sfdx auth:web:login -a tempDeploy

# Deploy the components
Write-Host "Deploying components..." -ForegroundColor Yellow
sfdx force:source:deploy -p "force-app/main/default"

# Deploy Named Credentials
Write-Host "Deploying Named Credentials..." -ForegroundColor Yellow
sfdx force:source:deploy -p $tempDir

# Clean up
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "`nInstallation completed!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Verify Named Credentials in Salesforce Setup" -ForegroundColor White
Write-Host "2. Add the googleSheetsList component to your Lightning page" -ForegroundColor White
Write-Host "3. Configure the component in Lightning App Builder" -ForegroundColor White

Write-Host "`nFor more information, please refer to the README.md file." -ForegroundColor Cyan
