# Run all EazyBank microservices locally (configserver -> eurekaserver -> gateway -> services)
# Usage: powershell -ExecutionPolicy Bypass -File .\run-local.ps1
$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$logsDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

$JAVA = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\java.exe" } else { "" }
if ([string]::IsNullOrWhiteSpace($JAVA) -or -not (Test-Path $JAVA)) {
    $jdk = Get-ChildItem -Path (Join-Path $env:USERPROFILE "jdks") -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "jdk-21*" } | Select-Object -First 1
    if (-not $jdk) { throw "JDK 21 not found. Set JAVA_HOME to a JDK 21 installation." }
    $env:JAVA_HOME = $jdk.FullName
    $JAVA = Join-Path $jdk.FullName "bin\java.exe"
}

# Guarantee a sane heap regardless of user env
$env:_JAVA_OPTIONS = "-Xmx1024M"

$svcs = @(
    @{ name = "configserver"; jar = "configserver-0.0.1-SNAPSHOT.jar"; port = 8071; wait = $true },
    @{ name = "eurekaserver"; jar = "eurekaserver-0.0.1-SNAPSHOT.jar"; port = 8070; wait = $true },
    @{ name = "gatewayserver"; jar = "gatewayserver-0.0.1-SNAPSHOT.jar"; port = 8072; wait = $true },
    @{ name = "accounts";     jar = "accounts-0.0.1-SNAPSHOT.jar";     port = 8080; wait = $true },
    @{ name = "cards";        jar = "cards-0.0.1-SNAPSHOT.jar";        port = 9000; wait = $true },
    @{ name = "loans";        jar = "loans-0.0.1-SNAPSHOT.jar";        port = 8090; wait = $true },
    @{ name = "message";      jar = "message-0.0.1-SNAPSHOT.jar";      port = 9010; wait = $false }
)

# Stop anything already running
if (Test-Path (Join-Path $PSScriptRoot "stop-local.ps1")) {
    & (Join-Path $PSScriptRoot "stop-local.ps1")
    Start-Sleep -Seconds 3
}

function Start-Svc($svc) {
    $jar = Join-Path $Root "$($svc.name)\target\$($svc.jar)"
    if (-not (Test-Path $jar)) {
        Write-Host "Missing $jar - run build.ps1 first." -ForegroundColor Red
        return $false
    }
    $out = Join-Path $logsDir "$($svc.name).log"
    $err = Join-Path $logsDir "$($svc.name).err.log"
    Start-Process -FilePath $JAVA -ArgumentList "-jar",$jar `
        -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden
    Write-Host "Starting $($svc.name) ..." -ForegroundColor Cyan
    return $true
}

function Wait-Port($port, $label, $timeoutSec = 240) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
            Write-Host "$label up on :$port" -ForegroundColor Green
            return $true
        }
        Start-Sleep -Seconds 3
    }
    Write-Host "$label did not come up on :$port - check logs\$label.log" -ForegroundColor Red
    return $false
}

# Sequential start: each service must be up before the next one boots
foreach ($svc in $svcs) {
    Start-Svc $svc | Out-Null
    if ($svc.wait -and -not (Wait-Port $svc.port $svc.name)) { exit 1 }
}

Write-Host ""
Write-Host "All services started. Logs: $logsDir" -ForegroundColor Green
Write-Host "Eureka dashboard   : http://localhost:8070/" -ForegroundColor Yellow
Write-Host "Config check       : http://localhost:8071/accounts/prod" -ForegroundColor Yellow
Write-Host "Gateway sample     : http://localhost:8072/eazybank/accounts/build-info" -ForegroundColor Yellow
Write-Host "Stop everything    : .\stop-local.ps1" -ForegroundColor Yellow