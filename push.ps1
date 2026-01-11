# PowerShell Script for Windows

# Set variables for Obsidian to Hugo copy
$sourcePath = "C:\Users\david\obsidian-vault\posts"
$destinationPath = "C:\Users\david\dwo.sh\content\posts"

# Set error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Change to the script's directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

# Check for required commands
$requiredCommands = @('git', 'hugo')

# Check for Python command (python or python3)
if (Get-Command 'python' -ErrorAction SilentlyContinue) {
    $pythonCommand = 'python'
} elseif (Get-Command 'python3' -ErrorAction SilentlyContinue) {
    $pythonCommand = 'python3'
} else {
    Write-Error "Python is not installed or not in PATH."
    exit 1
}

foreach ($cmd in $requiredCommands) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd is not installed or not in PATH."
        exit 1
    }
}

# Step 1: Sync posts from Obsidian to Hugo content folder using Robocopy
Write-Host "Syncing posts from Obsidian..."

if (-not (Test-Path $sourcePath)) {
    Write-Error "Source path does not exist: $sourcePath"
    exit 1
}

if (-not (Test-Path $destinationPath)) {
    Write-Error "Destination path does not exist: $destinationPath"
    exit 1
}

# Use Robocopy to mirror the directories
$robocopyOptions = @('/MIR', '/Z', '/W:5', '/R:3')
$robocopyResult = robocopy $sourcePath $destinationPath @robocopyOptions

if ($LASTEXITCODE -ge 8) {
    Write-Error "Robocopy failed with exit code $LASTEXITCODE"
    exit 1
}

# Step 2: Process Markdown files with Python script to handle image links
Write-Host "Processing image links in Markdown files..."
if (-not (Test-Path "images.py")) {
    Write-Error "Python script images.py not found."
    exit 1
}

# Execute the Python script
try {
    & $pythonCommand images-windows.py
} catch {
    Write-Error "Failed to process image links."
    exit 1
}

# Step 3: Build the Hugo site
Write-Host "Building the Hugo site..."
try {
    hugo
} catch {
    Write-Error "Hugo build failed."
    exit 1
}

# Step 4: cd into the public folder
Write-Host "Entering public directory..."
try {
    Set-Location public
} catch {
    Write-Error "Failed to enter public directory."
    exit 1
}


# Step 5: Add changes to Git
Write-Host "Staging changes for Git..."
$hasChanges = (git status --porcelain) -ne ""
if (-not $hasChanges) {
    Write-Host "No changes to stage."
} else {
    git add .
}

# Step 6: Commit changes with a dynamic message
$commitMessage = "Blog update on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$hasStagedChanges = (git diff --cached --name-only) -ne ""
if (-not $hasStagedChanges) {
    Write-Host "No changes to commit."
} else {
    Write-Host "Committing changes..."
    git commit -m "$commitMessage"
}

# Step 6: Push all changes to the main branch
Write-Host "Deploying to GitHub Main..."
try {
    git push origin main
} catch {
    Write-Error "Failed to push to Main branch."
    exit 1
}

# Step 7: cd back
Write-Host "Navigating back to original directory..."
try {
    Set-Location ..
} catch {
    Write-Error "Failed to enter original directory."
    exit 1
}
Write-Host "All done! Site synced, processed, committed, built, and deployed."
