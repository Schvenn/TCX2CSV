function tcx2csv {# Fitness Tracking: Extract data from TCX files, calculate step count, and export to CSV.

$currentDir = (Get-Location).Path; $outputCsvFilePath = Join-Path $currentDir "NewRuns.csv"; $stepData = @(); $tcxFiles = Get-ChildItem -Path $currentDir -Filter "*.tcx"

# Loop through each TCX file in the directory.
if (-not $tcxFiles) {Write-Host -ForegroundColor Red "`nNo TCX files found in the current directory.`n"; return}
foreach ($tcxFile in $tcxFiles) {[xml]$tcxData = Get-Content -Path $tcxFile.FullName; $namespace = "http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"; $nsManager = New-Object System.Xml.XmlNamespaceManager($tcxData.NameTable); $nsManager.AddNamespace("ns", $namespace); $activities = $tcxData.DocumentElement.SelectNodes("//ns:Activities/ns:Activity", $nsManager)

# Define format and pull data.
foreach ($activity in $activities) {$laps = $activity.SelectNodes("ns:Lap", $nsManager); $sport = if ($activity.Attributes["Sport"].Value -eq "Running") { "Run" } else { $activity.Attributes["Sport"].Value }
foreach ($lap in $laps) {$track = $lap.SelectSingleNode("ns:Track", $nsManager); $trackpoints = $track.SelectNodes("ns:Trackpoint", $nsManager); $lapStartTimeString = $lap.StartTime; if ($lapStartTimeString -eq $null) { continue }
$utcDateTime = [datetime]::ParseExact($lapStartTimeString, "yyyy-MM-ddTHH:mm:ssZ", $null); $timeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time"); $etDateTime = [System.TimeZoneInfo]::ConvertTime($utcDateTime, $timeZone); $lapTotalTime = $lap.TotalTimeSeconds; $lapDistance = $lap.DistanceMeters; $lapAverageHeartRateBpm = $lap.AverageHeartRateBpm.value; $lapCalories = [int]$lap.Calories

# Acquire MaxHeartRateBpm.
$maxHeartRate = $trackpoints | ForEach-Object {if ($_.HeartRateBpm.value -match '^\d+$') { [int]$_.HeartRateBpm.value } else { $null }} | Sort-Object -Descending | Select-Object -First 1

# Estimate steps.
$cadenceSum = 0; $cadenceCount = 0; foreach ($trackpoint in $trackpoints) {$cadence = $trackpoint.Cadence; $cadenceSum += $cadence; $cadenceCount++}
$approxStepCount = [math]::Round($cadenceSum / $cadenceCount * $lap.TotalTimeSeconds / 30); $approxStepCount = [int]($approxStepCount)
if ($approxStepCount -lt 1000) { continue }

# Redefine field formats.
$stepDataObject = [PSCustomObject]@{LapStartTime = $etDateTime.ToString("M/d/yyyy h:mm:ss tt"); Activity = $sport; Steps = $approxStepCount; Distance = [math]::Round($lapDistance / 1000, 2); Hours = ([int][math]::Floor($lapTotalTime / 3600)); Minutes = ([int][math]::Floor(($lapTotalTime % 3600) / 60)); Seconds = ([int]($lapTotalTime % 60)); AverageHeartRate = $lapAverageHeartRateBpm; MaxHeartRate = $maxHeartRate; Calories = $lapCalories}; $stepData += $stepDataObject}}}

# Merge data.
$existingData = @(); if (Test-Path $outputCsvFilePath) {$existingData = @((Import-Csv -Path $outputCsvFilePath))}
# Rename fields.
$stepData | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name "Date & Time" -Value $_.LapStartTime -Force; $_ | Add-Member -MemberType NoteProperty -Name "Kilometers" -Value $_.Distance -Force; $_ | Add-Member -MemberType NoteProperty -Name "h" -Value $_.Hours -Force; $_ | Add-Member -MemberType NoteProperty -Name "m" -Value $_.Minutes -Force; $_ | Add-Member -MemberType NoteProperty -Name "s" -Value $_.Seconds -Force; $_ | Add-Member -MemberType NoteProperty -Name "Average Pulse" -Value $_.AverageHeartRate -Force; $_ | Add-Member -MemberType NoteProperty -Name "Maximum HR" -Value $_.MaxHeartRate -Force; $_ | Add-Member -MemberType NoteProperty -Name "Reported Calories" -Value $_.Calories -Force
# Remove old fields.
$_.PSObject.Properties.Remove("LapStartTime"); $_.PSObject.Properties.Remove("Distance"); $_.PSObject.Properties.Remove("Hours"); $_.PSObject.Properties.Remove("Minutes"); $_.PSObject.Properties.Remove("Seconds"); $_.PSObject.Properties.Remove("AverageHeartRate"); $_.PSObject.Properties.Remove("MaxHeartRate"); $_.PSObject.Properties.Remove("Calories")}

# Merge, deduplicate, sort and export data.
$mergedData = $existingData + $stepData
$dedupDict = @{}; $dedupedData = foreach ($entry in $mergedData) {$key = @("$($entry.'Date & Time')", "$($entry.Activity)", "$($entry.Steps)", "$($entry.Kilometers)", "$($entry.h)", "$($entry.m)", "$($entry.s)", "$($entry.'Average Pulse')", "$($entry.'Maximum HR')", "$($entry.'Reported Calories')") -join '|'
if (-not $dedupDict.ContainsKey($key)) {$dedupDict[$key] = $true; $entry}}
$sortedData = $mergedData | Sort-Object "Date & Time" -Unique
$sortedData | Select-Object "Date & Time", "Activity", "Steps", "Kilometers", "h", "m", "s", "Average Pulse", "Maximum HR", "Reported Calories" | Export-Csv -Path $outputCsvFilePath -NoTypeInformation

# Confirm file contents and display it.
Write-Host -ForegroundColor Cyan "`n$outputCsvFilePath contains $($sortedData.Count) entries."
Import-Csv $outputCsvFilePath | Format-Table -AutoSize}
