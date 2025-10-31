$samples = @{}
Get-ChildItem -Recurse -Include @("*.wav", "*.WAV") | ForEach-Object {
    $relativePath = $_.FullName.Substring($PWD.Path.Length + 1).Replace('\', '/')
    $key = $relativePath.Split('/')[0]
    if (-not $samples.ContainsKey($key)) {
        $samples[$key] = @()
    }
    $samples[$key] += $relativePath
}

$finalSamples = @{}
foreach ($key in $samples.Keys) {
    if ($samples[$key].Count -eq 1) {
        $finalSamples[$key] = $samples[$key][0]
    } else {
        $finalSamples[$key] = $samples[$key]
    }
}

$finalSamples['_base'] = 'https://raw.githubusercontent.com/warsang/Samples/main'

$finalSamples | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 strudel.json