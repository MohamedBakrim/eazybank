# Build all EazyBank microservices + shared BOM/common library
# Usage: powershell -ExecutionPolicy Bypass -File .\build.ps1
$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

$JAVA = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\java.exe" } else { "" }
if ([string]::IsNullOrWhiteSpace($JAVA) -or -not (Test-Path $JAVA)) {
    $jdk = Get-ChildItem -Path (Join-Path $env:USERPROFILE "jdks") -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "jdk-21*" } | Select-Object -First 1
    if (-not $jdk) { throw "JDK 21 not found. Set JAVA_HOME to a JDK 21 installation." }
    $env:JAVA_HOME = $jdk.FullName
    $JAVA = Join-Path $jdk.FullName "bin\java.exe"
}

Push-Location $Root
try {
    & (Join-Path $Root "accounts\mvnw.cmd") -f "eazy-bom\pom.xml" clean install -DskipTests
    if ($LASTEXITCODE -ne 0) { throw "eazy-bom build failed" }
    foreach ($m in @("configserver","eurekaserver","gatewayserver","accounts","cards","loans","message")) {
        Write-Host "Building $m ..." -ForegroundColor Cyan
        & (Join-Path $Root "$m\mvnw.cmd") -f "$m\pom.xml" clean package -DskipTests
        if ($LASTEXITCODE -ne 0) { throw "$m build failed" }
    }
} finally { Pop-Location }
Write-Host "All modules built." -ForegroundColor Green