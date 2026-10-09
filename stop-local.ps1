# Stops all EazyBank microservices started with run-local.ps1
# Matches the executable jars produced by build.ps1, e.g. accounts-0.0.1-SNAPSHOT.jar
$jarPattern = "*-0.0.1-SNAPSHOT.jar"
Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
    Where-Object { $_.CommandLine -like "*-jar*" -and $_.CommandLine -like $jarPattern } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force
        Write-Host "Stopped PID $($_.ProcessId)"
    }
