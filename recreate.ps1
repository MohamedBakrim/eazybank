# Recreate the entire EazyBank Kubernetes environment from manifests
# Usage: powershell -ExecutionPolicy Bypass -File .\recreate.ps1
$ErrorActionPreference = "Stop"

Write-Host "`n=== Phase 1: Destroy ===" -ForegroundColor Yellow
if (kubectl get namespace eazybank 2>$null) {
    kubectl delete namespace eazybank --wait=true --timeout=120s
    Write-Host "Namespace eazybank deleted" -ForegroundColor Red
} else {
    Write-Host "Namespace eazybank does not exist yet" -ForegroundColor DarkGray
}

Write-Host "`n=== Phase 2: Create ===" -ForegroundColor Yellow
kubectl apply -f k8s/namespace.yaml
kubectl apply -R -f k8s/
Write-Host "All manifests applied" -ForegroundColor Green

Write-Host "`n=== Phase 3: Wait for infrastructure ===" -ForegroundColor Yellow

$infra = @("redis", "kafka", "keycloak", "configserver", "eurekaserver")
foreach ($svc in $infra) {
    Write-Host "  Waiting for $svc..." -NoNewline
    kubectl rollout status deployment/$svc -n eazybank --timeout=300s 2>$null | Out-Null
    Write-Host " ready" -ForegroundColor Green
}

Write-Host "`n=== Phase 4: Restart apps (configserver + eureka now available) ===" -ForegroundColor Yellow

$apps = @("accounts", "cards", "loans", "message", "gatewayserver")
foreach ($app in $apps) {
    kubectl rollout restart deployment/$app -n eazybank 2>$null | Out-Null
    Write-Host "  Restarting $app" -ForegroundColor Cyan
}

foreach ($app in $apps) {
    Write-Host "  Waiting for $app..." -NoNewline
    kubectl rollout status deployment/$app -n eazybank --timeout=300s 2>$null | Out-Null
    Write-Host " ready" -ForegroundColor Green
}

Write-Host "`n=== Phase 5: Smoke test ===" -ForegroundColor Yellow

$pass = 0; $fail = 0
$deadline = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri "http://localhost/eazybank/accounts/contact-info" -UseBasicParsing -TimeoutSec 10
        if ($r.StatusCode -eq 200 -and $r.Content -match "contactDetails") {
            Write-Host "  PASS  gateway -> accounts -> HTTP 200" -ForegroundColor Green
            $pass++
            break
        }
    } catch {}
    Start-Sleep -Seconds 5
}
if ($pass -eq 0) {
    Write-Host "  FAIL  no healthy response within 60s" -ForegroundColor Red
    $fail++
}

Write-Host "`n=== Result: $pass passed, $fail failed ===" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
Write-Host "Gateway (ingress)   : http://localhost/eazybank/accounts/contact-info" -ForegroundColor Yellow
Write-Host "Gateway (LB direct) : http://localhost:8072/eazybank/accounts/contact-info" -ForegroundColor Yellow
