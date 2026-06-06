function gpx2csv ([int]$Weight, [switch]$help) {# Fitness Tracking: Extract data from GPX files, calculate step count, and export to CSV.

$currentDir = (Get-Location).Path; $outputCsvFilePath = Join-Path $currentDir "NewRuns.csv"; $stepData = @(); $gpxFiles = Get-ChildItem -Path $currentDir -Filter "*.gpx"

# Load configuration.
function loadconfiguration {$script:powershell = Split-Path $profile; $script:baseModulePath = "$powershell\Modules\GPX2CSV"; $script:configPath = Join-Path $baseModulePath "GPX2CSV.psd1"
if (!(Test-Path $configPath)) {throw "Config file not found at $configPath"}
$script:config = Import-PowerShellDataFile -Path $configPath

# Pull config values into variables
$script:weight = $config.privatedata.weight}
loadconfiguration
if ($weight) {$script:weight = $weight}

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

function help {# Inline help.
function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
line yellow 100 -pre; $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; line yellow 100
if ($lines.Count -gt 1) {wordwrap $lines[1] 100 | Write-Host -f white | Out-Host -Paging}; line yellow 100}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}

$selection = $null
do {cls; Write-Host "$(Get-ChildItem (Split-Path $PSCommandPath) | Where-Object {$_.FullName -ieq $PSCommandPath} | Select-Object -ExpandProperty BaseName) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host "$($i + 1). " -f cyan -n; Write-Host $sections[$i].Groups[1].Value -f white}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
Write-Host -f yellow "`nEnter a section number to view " -n; $input = Read-Host
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

# External call to help.
if ($help) {help; return}

# Calculate distance
function Get-DistanceMeters ($lat1, $lon1, $lat2, $lon2) {$R = 6371000; $dLat = ($lat2 - $lat1) * [math]::PI / 180; $dLon = ($lon2 - $lon1) * [math]::PI / 180; $a = [math]::Sin($dLat/2) * [math]::Sin($dLat/2) + [math]::Cos($lat1 * [math]::PI / 180) * [math]::Cos($lat2 * [math]::PI / 180) * [math]::Sin($dLon/2) * [math]::Sin($dLon/2); $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1-$a)); return $R * $c}

# Loop through each relevant file in the directory and calculate measurements.
if (-not $gpxFiles) {Write-Host -f red "`nNo GPX files found in the current directory.`n"; return}
foreach ($gpxFile in $gpxFiles) {[xml]$gpx = Get-Content $gpxFile.FullName; $ns = New-Object System.Xml.XmlNamespaceManager($gpx.NameTable); $ns.AddNamespace("gpx", "http://www.topografix.com/GPX/1/1"); $ns.AddNamespace("gpxtpx", "http://www.garmin.com/xmlschemas/TrackPointExtension/v1"); $tracks = $gpx.DocumentElement.SelectNodes("gpx:trk", $ns)
foreach ($track in $tracks) {$trackName = $track.name; $points = $track.SelectNodes(".//gpx:trkpt", $ns)
if ($points.Count -lt 2) {continue}
$startTime = [datetime]::Parse($points[0].time); $endTime = [datetime]::Parse($points[$points.Count - 1].time); $totalSeconds = ($endTime - $startTime).TotalSeconds
if ($totalSeconds -lt 60) {continue}
$latPrev = $null; $lonPrev = $null; $totalDistance = 0; $cadenceSum = 0; $cadenceCount = 0; $hrValues = @()
foreach ($p in $points) {$lat = [double]$p.Attributes["lat"].Value; $lon = [double]$p.Attributes["lon"].Value
if ($latPrev -ne $null) {$totalDistance += Get-DistanceMeters $latPrev $lonPrev $lat $lon}
$latPrev = $lat; $lonPrev = $lon; $hrNode = $p.SelectSingleNode("gpx:extensions/gpxtpx:TrackPointExtension/gpxtpx:hr", $ns); $cadNode = $p.SelectSingleNode("gpx:extensions/gpxtpx:TrackPointExtension/gpxtpx:cad", $ns)
if ($hrNode -and $hrNode.InnerText -match '^\d+$') {$hrValues += [int]$hrNode.InnerText}
if ($cadNode -and $cadNode.InnerText -match '^\d+$') {$cadenceSum += [int]$cadNode.InnerText; $cadenceCount++}}
$avgHR = if ($hrValues.Count) {[math]::Round(($hrValues | Measure-Object -Average).Average)}
else {0}
$avgCadence = if ($cadenceCount) {$cadenceSum / $cadenceCount}
else {0}
if ($avgCadence -gt 0) {$approxStepCount = [math]::Round($avgCadence * $totalSeconds / 60)}
else {$approxStepCount = [math]::Round(1.25 * $totalSeconds)}
if ($totalSeconds -lt 60) {continue}

$stepData += [PSCustomObject]@{LapStartTime = $startTime
Activity = "Run"
Steps = $approxStepCount
Distance = [math]::Round($totalDistance / 1000, 2)
Hours = [int][math]::Floor($totalSeconds / 3600)
Minutes = [int][math]::Floor(($totalSeconds % 3600) / 60)
Seconds = [int]($totalSeconds % 60)
AverageHeartRate = $avgHR
MaxHeartRate = if ($hrValues.Count) {($hrValues | Measure-Object -Maximum).Maximum}
else {0}
Calories = if ($script:weight) {[math]::Round(9.8 * $script:weight * ($totalSeconds / 3600))}
else {0}}}}

# Merge data.
$existingData = @(); if (Test-Path $outputCsvFilePath) {$existingData = @((Import-Csv -Path $outputCsvFilePath))}
# Rename fields.
$stepData | ForEach-Object {$_ | Add-Member -MemberType NoteProperty -Name "Date & Time" -Value $_.LapStartTime -Force; $_ | Add-Member -MemberType NoteProperty -Name "Kilometers" -Value $_.Distance -Force; $_ | Add-Member -MemberType NoteProperty -Name "h" -Value $_.Hours -Force; $_ | Add-Member -MemberType NoteProperty -Name "m" -Value $_.Minutes -Force; $_ | Add-Member -MemberType NoteProperty -Name "s" -Value $_.Seconds -Force; $_ | Add-Member -MemberType NoteProperty -Name "Average Pulse" -Value $_.AverageHeartRate -Force; $_ | Add-Member -MemberType NoteProperty -Name "Maximum HR" -Value $_.MaxHeartRate -Force; $_ | Add-Member -MemberType NoteProperty -Name "Reported Calories" -Value $_.Calories -Force
# Remove old fields.
$_.PSObject.Properties.Remove("LapStartTime"); $_.PSObject.Properties.Remove("Distance"); $_.PSObject.Properties.Remove("Hours"); $_.PSObject.Properties.Remove("Minutes"); $_.PSObject.Properties.Remove("Seconds"); $_.PSObject.Properties.Remove("AverageHeartRate"); $_.PSObject.Properties.Remove("MaxHeartRate"); $_.PSObject.Properties.Remove("Calories")}

# Load existing
$seen = @{}
$newUnique = foreach ($entry in $stepData) {$k = "$($entry.'Date & Time')|$($entry.Activity)"
if (-not $seen.ContainsKey($k)) {$seen[$k] = $true; $entry}}

# Final dataset = old + new unique
$final = $existingData + $newUnique
$sortedData = $final | Where-Object {$_.'Date & Time' -and $_.'Date & Time' -ne ''} | Sort-Object {[datetime]::Parse($_.'Date & Time')}
$sortedData | Select-Object "Date & Time","Activity","Steps","Kilometers","h","m","s","Average Pulse","Maximum HR","Reported Calories" -unique | Export-Csv -Path $outputCsvFilePath -NoTypeInformation

# Confirm file contents and display it.
Write-Host -f cyan "`n$outputCsvFilePath contains $($sortedData.Count) entries."
Import-Csv $outputCsvFilePath | Format-Table -AutoSize
if ($gpxFiles) {Recycle "*.gpx"}
./NewRuns.csv}

Export-ModuleMember -Function gpx2csv

<#
## GPX2CSV
Download a GPX file from a service such as Strava and run this script in that directory, in order to parse the important parts of it into a CSV file.

usage: GPX2CSV <weight in kg>

You do not need to provide a weight, but if you do not, the script will use the default provided in the accompanying PSD1 file. For those of you who do not know the metric system, divide your weight in pounds (lbs) by 2.2 to get your metric equivalent in kilograms.
## License
MIT License

Copyright © 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
##>
