#!/usr/bin/env pwsh

# Read the file and remove the unused methods
$content = Get-Content "c:\Users\Jim\Documents\EcoKuha\ Tracker\EcoKuha\EcoKuha\ecokuha\lib\features\junkshop\presentation\screens\dashboard_screen.dart"

# Find lines to remove (methods that are unused)
$newContent = @()
$skipLines = $false
$methodStart = $false

for ($i = 0; $i -lt $content.Length; $i++) {
    $line = $content[$i]
    
    # Check if this is the start of an unused method
    if ($line -match "Widget _buildHeader\(\)") {
        $skipLines = $true
        $methodStart = $true
        continue
    }
    if ($line -match "Widget _buildBottomNavigation\(\)") {
        $skipLines = $true
        $methodStart = $true
        continue
    }
    if ($line -match "Widget _buildCashierButton\(\)") {
        $skipLines = $true
        $methodStart = $true
        continue
    }
    
    # If we're skipping and find the end of the method
    if ($skipLines -and $line -match "^\s*\}\s*$" -and -not $methodStart) {
        $skipLines = $false
        continue
    }
    
    if ($methodStart) {
        $methodStart = $false
    }
    
    # Add the line if we're not skipping
    if (-not $skipLines) {
        $newContent += $line
    }
}

# Write the cleaned content back
$newContent | Set-Content "c:\Users\Jim\Documents\EcoKuha\ Tracker\EcoKuha\EcoKuha\ecokuha\lib\features\junkshop\presentation\screens\dashboard_screen.dart"