[CmdletBinding()]
param(
    [ValidatePattern('^emulator-\d+$')]
    [string]$Device = 'emulator-5554'
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path integration-artifacts -Force | Out-Null

for ($run = 1; $run -le 3; $run++) {
    $logPath = "integration-artifacts/journey-$run.log"
    $command = "flutter test integration_test/payment_journey_test.dart -d $Device --flavor dev --dart-define-from-file=config/dev.json --dart-define=SENTRY_DSN= --no-pub --reporter expanded 2>&1"

    cmd.exe /d /c $command | Tee-Object -FilePath $logPath

    if ($LASTEXITCODE -ne 0) {
        throw "Journey run $run failed. See $logPath."
    }

    $entry = Select-String -Path $logPath -Pattern 'INTEGRATION_SCREENSHOT=(.+)' |
        Select-Object -Last 1

    if ($null -eq $entry) {
        throw "Run $run did not report a screenshot."
    }

    $androidPath = $entry.Matches[0].Groups[1].Value.Trim()
    $outputPath = "integration-artifacts/cycle-paid-$run.png"
    $copyCommand = 'adb -s {0} exec-out run-as za.co.kgomotsonthuping.ronditrack.dev cat "{1}" > "{2}"' -f $Device, $androidPath, $outputPath

    cmd.exe /d /c $copyCommand

    if ($LASTEXITCODE -ne 0) {
        throw "Could not copy the screenshot for run $run."
    }
}

Write-Host 'Three consecutive journey runs passed. Evidence is in integration-artifacts.'