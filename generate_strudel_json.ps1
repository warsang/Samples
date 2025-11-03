# Main script logic
$samples = @{}
$baseDir = $PWD.Path

# Drum abbreviation mapping
$drumMap = @{
    bd = @("kick", "bassdrum", "bd", "kick1", "kick5")
    sd = @("snare", "snaredrum", "sd")
    rim = @("rim", "rimshot")
    cp = @("clap", "handclap", "TR707_CLAP")
    hh = @("closedhat", "hihat_closed", "hh", "808hh", "ch", "wa_808tape_closedhat_08_clean")
    oh = @("openhat", "hihat_open", "oh", "505_OPEN_HH")
    cr = @("crash", "wa_808tape_crash_03_sat")
    rd = @("ride")
    ht = @("hightom", "tomtom_high", "ht")
    mt = @("midtom", "tomtom_mid", "mt")
    lt = @("lowtom", "tomtom_low", "lt")
    agogo_high = @("agogo_high")
    agogo_low = @("agogo_low")
    bongo_mute = @("bongo_mute")
    bongo_rim = @("bongo_rim")
    bongo = @("bongo")
    cabasa = @("cabasa")
    conga_high = @("conga_high")
    conga_low = @("conga_low")
    conga_mute = @("conga_mute")
    conga_rim = @("conga_rim")
    cowbell = @("cowbell")
    handclap = @("handclap")
    hihat_pedal = @("hihat_pedal")
    maracas = @("maracas")
}

# Function to sanitize names for JSON keys
function Sanitize-Name($name) {
    return $name.ToLower() -replace '\[kb6\]', '' -replace '[^a-z0-9]', ''
}

# Get top-level directories, excluding .git
$topLevelDirs = Get-ChildItem -Path $baseDir -Directory | Where-Object { $_.Name -ne ".git" }

foreach ($dir in $topLevelDirs) {
    $subDirs = Get-ChildItem -Path $dir.FullName -Directory
    
    if ($subDirs.Count -eq 0) {
        # No subdirectories, treat as a single instrument
        $files = Get-ChildItem -Path $dir.FullName -Recurse -Include @("*.wav", "*.WAV")
        if ($files.Count -gt 0) {
            $key = Sanitize-Name($dir.Name)
            $samples[$key] = $files | ForEach-Object { $_.FullName.Substring($baseDir.Length + 1).Replace('\', '/') }
        }
    } else {
        # Process each subdirectory as an instrument
        foreach ($subDir in $subDirs) {
            $instrumentName = Sanitize-Name($subDir.Name)
            $filesInSubDir = Get-ChildItem -Path $subDir.FullName -Recurse -Include @("*.wav", "*.WAV")

            if ($filesInSubDir.Count -eq 0) {
                continue
            }

            if ($dir.Name -eq "Drums") {
                # Special handling for Drums folder
                $drumKit = @{}
                foreach ($file in $filesInSubDir) {
                    $fileNameLower = $file.Name.ToLower()
                    $found = $false
                    foreach ($drumKey in $drumMap.Keys) {
                        foreach ($pattern in $drumMap[$drumKey]) {
                            if ($fileNameLower -like "*$pattern*") {
                                $relativePath = $file.FullName.Substring($baseDir.Length + 1).Replace('\', '/')
                                $drumKit[$drumKey] = $relativePath
                                $found = $true
                                break
                            }
                        }
                        if ($found) { break }
                    }
                }
                
                if ($drumKit.Count -gt 0) {
                    if ($samples.ContainsKey($instrumentName)) {
                        # Merge with existing drumkit if key already exists
                        foreach($key in $drumKit.Keys) {
                           $samples[$instrumentName][$key] = $drumKit[$key]
                        }
                    } else {
                        $samples[$instrumentName] = $drumKit
                    }
                } else {
                    # FALLBACK: If no drum patterns matched, add the raw file list for inspection.
                    $samples[$instrumentName] = $filesInSubDir | ForEach-Object { $_.FullName.Substring($baseDir.Length + 1).Replace('\', '/') }
                }

            } else {
                # Generic handling for other folders with subdirs
                $key = Sanitize-Name($subDir.Name)
                $samples[$key] = $filesInSubDir | ForEach-Object { $_.FullName.Substring($baseDir.Length + 1).Replace('\', '/') }
            }
        } 
    }
    # Also process files in the root of the top-level dir
    $filesInRoot = Get-ChildItem -Path $dir.FullName -Include @("*.wav", "*.WAV")
    if($filesInRoot.Count -gt 0) {
        if ($dir.Name -eq "Drums") {
            $instrumentName = Sanitize-Name($dir.Name)
            if (!$samples.ContainsKey($instrumentName)) {
                $samples[$instrumentName] = @{}
            }
            foreach ($file in $filesInRoot) {
                $fileNameLower = $file.Name.ToLower()
                $found = $false
                foreach ($drumKey in $drumMap.Keys) {
                    foreach ($pattern in $drumMap[$drumKey]) {
                        if ($fileNameLower -like "*$pattern*") {
                            $relativePath = $file.FullName.Substring($baseDir.Length + 1).Replace('\', '/')
                            $samples[$instrumentName][$drumKey] = $relativePath
                            $found = true
                            break
                        }
                    }
                    if ($found) { break }
                }
            }
        } else {
             $key = Sanitize-Name($dir.Name)
             if (!$samples.ContainsKey($key)) {
                $samples[$key] = @()
             }
             $samples[$key] += $filesInRoot | ForEach-Object { $_.FullName.Substring($baseDir.Length + 1).Replace('\', '/') }
        }
    }
}

# Final processing to handle single vs multiple samples
$finalSamples = @{}
foreach ($key in $samples.Keys) {
    if ($samples[$key] -is [hashtable]) {
        $finalSamples[$key] = $samples[$key]
    } elseif ($samples[$key].Count -eq 1) {
        $finalSamples[$key] = $samples[$key][0]
    } else {
        $finalSamples[$key] = $samples[$key]
    }
}


$finalSamples['_base'] = 'https://raw.githubusercontent.com/warsang/Samples/main'

$finalSamples | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 strudel.json