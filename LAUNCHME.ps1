<#
.SYNOPSIS
Proves that the subdirectory module github.com/aws/aws-sdk-go-v2/service/s3
resolves straight from its GitHub tag, then runs the test and the demo.

.DESCRIPTION
Uses a fresh, empty module cache and bypasses proxy.golang.org (GOPROXY=direct),
so Go must clone the repository and check out the tag service/s3/<version>.
The Go environment variables are restored and the temporary cache is deleted
when the script finishes. Your own module cache is never touched.
#>
param (
    [string]$Module = "github.com/aws/aws-sdk-go-v2/service/s3",
    [switch]$KeepCache
)
$ErrorActionPreference = "Stop"

function Write-Banner([string]$Text) {
    $line = "═" * ($Text.Length + 4)
    Write-Host ""
    Write-Host "╔$line╗" -ForegroundColor Cyan
    Write-Host "║  $Text  ║" -ForegroundColor Cyan
    Write-Host "╚$line╝" -ForegroundColor Cyan
}

function Write-Step([int]$Number, [string]$Text) {
    Write-Host ""
    Write-Host " $Number " -BackgroundColor DarkCyan -ForegroundColor White -NoNewline
    Write-Host " $Text" -ForegroundColor White
}

function Write-Field([string]$Name, [string]$Value, [string]$Color = "Gray") {
    Write-Host ("   {0,-14}" -f $Name) -ForegroundColor DarkGray -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

function Write-Result([bool]$Ok, [string]$Text, [TimeSpan]$Elapsed) {
    $time = "({0:0.0}s)" -f $Elapsed.TotalSeconds
    if ($Ok) {
        Write-Host "   ✔ $Text " -ForegroundColor Green -NoNewline
    } else {
        Write-Host "   ✘ $Text " -ForegroundColor Red -NoNewline
    }
    Write-Host $time -ForegroundColor DarkGray
}

# Runs a go command, indenting its output; returns whether it succeeded.
function Invoke-Go([string[]]$GoArgs) {
    Write-Host "   > go $($GoArgs -join ' ')" -ForegroundColor DarkYellow
    $watch = [Diagnostics.Stopwatch]::StartNew()
    & go @GoArgs 2>&1 | ForEach-Object {
        $text = "$_"
        $color = "Gray"
        if ($text -match '^(--- )?PASS|^ok\s') { $color = "Green" }
        elseif ($text -match '^(--- )?FAIL|error') { $color = "Red" }
        elseif ($text -match '^go: downloading') { $color = "DarkGray" }
        Write-Host "   │ $text" -ForegroundColor $color
    }
    $ok = $LASTEXITCODE -eq 0
    return @{ Ok = $ok; Elapsed = $watch.Elapsed }
}

$goVars = "GOMODCACHE", "GOPROXY", "GOFLAGS"
$saved = @{}
foreach ($name in $goVars) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }

$cache = Join-Path ([IO.Path]::GetTempPath()) ("go-subdir-mod-test-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
$results = [ordered]@{}

Push-Location $PSScriptRoot
try {
    Write-Banner "Go module from a repository subdirectory"
    Write-Field "Module" $Module White
    Write-Field "Go" ((go version) -replace '^go version ', '')
    Write-Field "Cache" "$cache (new, empty)"
    Write-Field "Proxy" "off (GOPROXY=direct, fetched from GitHub)"

    New-Item -ItemType Directory -Path $cache | Out-Null
    $env:GOMODCACHE = $cache
    $env:GOPROXY = "direct"
    $env:GOFLAGS = "-modcacherw"   # lets the temporary cache be deleted afterwards

    # 1. Download and show where the module came from
    Write-Step 1 "Resolve the module from GitHub"
    $version = (go list -m -f '{{.Version}}' $Module)
    Write-Host "   > go mod download -json $Module@$version" -ForegroundColor DarkYellow
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $json = go mod download -json "$Module@$version"
    $ok = $LASTEXITCODE -eq 0
    if ($ok) {
        $info = $json | ConvertFrom-Json
        $origin = $info.Origin
        $tag = $origin.Ref -replace '^refs/tags/', ''
        Write-Field "Version" $info.Version White
        Write-Field "Repository" $origin.URL
        Write-Field "Subdirectory" $origin.Subdir Yellow
        Write-Field "Tag" $tag Yellow
        Write-Field "Commit" $origin.Hash
        Write-Field "Module hash" $info.Sum
        Write-Field "Browse" "$($origin.URL)/tree/$tag/$($origin.Subdir)" Cyan
    } else {
        $json | ForEach-Object { Write-Host "   │ $_" -ForegroundColor Red }
    }
    Write-Result $ok "Resolved from tag" $watch.Elapsed
    $results["Resolve from GitHub tag"] = $ok

    # 2. Unit test of the s3lib wrapper
    Write-Step 2 "Test the s3lib wrapper"
    $r = Invoke-Go @("test", "-count=1", "-v", "./...")
    Write-Result $r.Ok "go test" $r.Elapsed
    $results["go test ./..."] = $r.Ok

    # 3. Demo program
    Write-Step 3 "Run the demo"
    $r = Invoke-Go @("run", ".")
    Write-Result $r.Ok "go run" $r.Elapsed
    $results["go run ."] = $r.Ok
}
finally {
    foreach ($name in $goVars) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    Pop-Location
    if ((Test-Path $cache) -and -not $KeepCache) {
        Remove-Item -Recurse -Force $cache
    }
}

Write-Banner "Summary"
foreach ($entry in $results.GetEnumerator()) {
    if ($entry.Value) {
        Write-Host "   ✔ $($entry.Key)" -ForegroundColor Green
    } else {
        Write-Host "   ✘ $($entry.Key)" -ForegroundColor Red
    }
}
if ($KeepCache) {
    Write-Host "   Cache kept at $cache" -ForegroundColor DarkGray
} else {
    Write-Host "   Temporary cache removed; Go environment restored." -ForegroundColor DarkGray
}
Write-Host ""

if ($results.Values -contains $false) { exit 1 }
