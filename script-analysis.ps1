# Install-Module -Name PSScriptAnalyzer -Force
$results = Invoke-ScriptAnalyzer -Path .\yt-dlp-helper.ps1
$results | Format-Table -AutoSize | Tee-Object -FilePath analysis-results.txt
if ($results) { throw "Script analysis found issues" }
