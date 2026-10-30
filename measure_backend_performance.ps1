$Host.UI.RawUI.WindowTitle = "AI Journal Companion - Backend Performance Test"

$samples = @(
    "I feel calm and relaxed after spending a quiet afternoon reading.",
    "I am excited about completing my project and showing it tomorrow.",
    "I feel frustrated because the same problem keeps stopping my progress.",
    "I am worried that I will not finish everything before the deadline.",
    "I had a wonderful day with my friends and feel very happy.",
    "Today was ordinary and I do not feel strongly about anything."
)

$results = @()

Write-Host "AI JOURNAL COMPANION - EMOTION DETECTION RESPONSIVENESS" -ForegroundColor Cyan
Write-Host "Endpoint: http://127.0.0.1:8000/analyze"
Write-Host "Test time: $(Get-Date -Format 'dd MMMM yyyy HH:mm:ss')"
Write-Host ""

for ($index = 0; $index -lt $samples.Count; $index++) {
    $requestBody = @{
        text = $samples[$index]
    } | ConvertTo-Json -Compress

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $response = Invoke-RestMethod `
            -Uri "http://127.0.0.1:8000/analyze" `
            -Method Post `
            -ContentType "application/json" `
            -Body $requestBody `
            -TimeoutSec 130

        $stopwatch.Stop()

        $results += [PSCustomObject]@{
            Run = $index + 1
            Type = if ($index -eq 0) { "First observed" } else { "Steady-state" }
            Emotion = $response.emotion
            Seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
            Success = "Yes"
        }
    }
    catch {
        $stopwatch.Stop()

        $results += [PSCustomObject]@{
            Run = $index + 1
            Type = if ($index -eq 0) { "First observed" } else { "Steady-state" }
            Emotion = "ERROR"
            Seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
            Success = "No"
        }
    }
}

$results | Format-Table -AutoSize

$steadyState = @(
    $results |
        Where-Object {
            $_.Run -gt 1 -and $_.Success -eq "Yes"
        }
)

$sortedTimes = @(
    $steadyState.Seconds | Sort-Object
)

$average = (
    $sortedTimes | Measure-Object -Average
).Average

$median = if ($sortedTimes.Count % 2 -eq 1) {
    $sortedTimes[[math]::Floor($sortedTimes.Count / 2)]
}
else {
    (
        $sortedTimes[$sortedTimes.Count / 2 - 1] +
        $sortedTimes[$sortedTimes.Count / 2]
    ) / 2
}

$successCount = @(
    $results | Where-Object Success -eq "Yes"
).Count

Write-Host "STEADY-STATE SUMMARY" -ForegroundColor Yellow
Write-Host "Minimum: $([math]::Round(($sortedTimes | Measure-Object -Minimum).Minimum, 2)) seconds"
Write-Host "Maximum: $([math]::Round(($sortedTimes | Measure-Object -Maximum).Maximum, 2)) seconds"
Write-Host "Average: $([math]::Round($average, 2)) seconds"
Write-Host "Median:  $([math]::Round($median, 2)) seconds"
Write-Host "Range:   $([math]::Round((($sortedTimes | Measure-Object -Maximum).Maximum - ($sortedTimes | Measure-Object -Minimum).Minimum), 2)) seconds"
Write-Host "Successful requests: $successCount of $($results.Count)"
Write-Host "Success rate: $([math]::Round(($successCount / $results.Count) * 100, 0))%"
Write-Host ""
Write-Host "Timing includes FastAPI, Ollama inference, JSON processing, and the returned response."
Write-Host ""
Read-Host "Press Enter to close"
