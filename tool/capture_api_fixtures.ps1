param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,
    [switch]$MeasureDatabaseFailure
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$fixtureDirectory = Join-Path $repoRoot "test\fixtures\api"
$baseAddress = $ApiBaseUrl.TrimEnd("/")
$securePassword = Read-Host "API seed password" -AsSecureString

try {
    $plainPassword = [System.Net.NetworkCredential]::new(
        "",
        $securePassword
    ).Password

    $loginBody = @{
        email = "lerato@ronditrack.co.za"
        password = $plainPassword
    } | ConvertTo-Json -Compress

    $loginResponse = Invoke-RestMethod `
        -Method Post `
        -Uri "$baseAddress/api/v1/auth/login" `
        -ContentType "application/json" `
        -Body $loginBody `
        -ErrorAction Stop

    $requestHeaders = @{
        Authorization = "Bearer $($loginResponse.accessToken)"
    }

    $dashboardResponse = Invoke-RestMethod `
        -Uri "$baseAddress/api/v1/me/home" `
        -Headers $requestHeaders `
        -ErrorAction Stop

    $familyEntry = @($dashboardResponse.stokvels) |
        Where-Object { $_.name -eq "Family Savers" } |
        Select-Object -First 1

    if ($null -eq $familyEntry) {
        throw "The expected seed membership is missing."
    }

    $stokvelId = [uri]::EscapeDataString(
        [string]$familyEntry.stokvelId
    )

    $stokvelResponse = Invoke-RestMethod `
        -Uri "$baseAddress/api/v1/stokvels/$stokvelId" `
        -Headers $requestHeaders `
        -ErrorAction Stop

    $cyclesResponse = Invoke-RestMethod `
        -Uri "$baseAddress/api/v1/stokvels/$stokvelId/cycles" `
        -Headers $requestHeaders `
        -ErrorAction Stop

    $membersResponse = Invoke-RestMethod `
        -Uri "$baseAddress/api/v1/stokvels/$stokvelId/members?PageSize=20" `
        -Headers $requestHeaders `
        -ErrorAction Stop

    $contributionsResponse = Invoke-RestMethod `
        -Uri "$baseAddress/api/v1/stokvels/$stokvelId/contributions?pageSize=20" `
        -Headers $requestHeaders `
        -ErrorAction Stop

    if (
        ![string]::IsNullOrEmpty(
            [string]$membersResponse.nextPageToken
        ) -or
        ![string]::IsNullOrEmpty(
            [string]$contributionsResponse.nextPageToken
        )
    ) {
        throw "Use a fresh seed with terminal fixture pages."
    }

    New-Item `
        -ItemType Directory `
        -Path $fixtureDirectory `
        -Force `
        -ErrorAction Stop | Out-Null

    $payloads = @{
        "home.json" = $dashboardResponse
        "stokvel.json" = $stokvelResponse
        "cycles.json" = @($cyclesResponse)
        "members.json" = $membersResponse
        "contributions.json" = $contributionsResponse
    }

    $utf8 = [System.Text.UTF8Encoding]::new($false)

    foreach ($entry in $payloads.GetEnumerator()) {
        $destination = Join-Path $fixtureDirectory $entry.Key
        $json = ConvertTo-Json -InputObject $entry.Value -Depth 100
        [System.IO.File]::WriteAllText($destination, $json, $utf8)
    }

    Write-Output "Saved five API response fixtures."

    if ($MeasureDatabaseFailure) {
        [void](Read-Host "Stop your disposable local database, then press Enter")

        $statusCode = $null
        $reference = $null
        $timer = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $probeResponse = Invoke-WebRequest `
                -Uri "$baseAddress/api/v1/me/home" `
                -Headers $requestHeaders `
                -TimeoutSec 180 `
                -UseBasicParsing `
                -ErrorAction Stop

            $statusCode = [int]$probeResponse.StatusCode
        }
        catch {
            if ($null -ne $_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            if ($null -ne $_.ErrorDetails) {
                try {
                    $problem = ConvertFrom-Json `
                        -InputObject $_.ErrorDetails.Message `
                        -ErrorAction Stop

                    $candidate = [string]$problem.correlationId

                    if ($candidate -match "^[A-Za-z0-9._:-]{1,128}$") {
                        $reference = $candidate
                    }
                }
                catch {}
            }
        }
        finally {
            $timer.Stop()
        }

        $evidenceDirectory = Join-Path $repoRoot "docs\evidence"

        New-Item `
            -ItemType Directory `
            -Path $evidenceDirectory `
            -Force `
            -ErrorAction Stop | Out-Null

        $measurement = @{
            capturedAtUtc = [DateTime]::UtcNow.ToString("O")
            statusCode = $statusCode
            elapsedMilliseconds = $timer.ElapsedMilliseconds
            correlationId = $reference
        }

        $measurementPath = Join-Path `
            $evidenceDirectory `
            "api-db-down.json"

        [System.IO.File]::WriteAllText(
            $measurementPath,
            (ConvertTo-Json -InputObject $measurement),
            $utf8
        )

        Write-Output "Saved database-failure timing evidence."
        [void](Read-Host "Restart your local database, then press Enter")
    }
}
catch {
    throw "Capture failed. Check the running API, fresh seed and password."
}
finally {
    $plainPassword = $null
    $loginBody = $null
    $loginResponse = $null
    $requestHeaders = $null
    $securePassword.Dispose()
}