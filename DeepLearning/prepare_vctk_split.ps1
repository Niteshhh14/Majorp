param(
    [string]$CorpusRoot = "../Data/Speech/VCTK-Corpus-0.92/wav48_silence_trimmed",
    [string]$Output = "splits/vctk_speaker_split.csv",
    [int]$Seed = 271828
)

$ErrorActionPreference = 'Stop'
$corpusPath = if ([System.IO.Path]::IsPathRooted($CorpusRoot)) { $CorpusRoot } else { Join-Path $PSScriptRoot $CorpusRoot }
$root = (Resolve-Path -LiteralPath $corpusPath).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$outPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $Output))
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Use mic1 only, and assign whole speakers to a split to prevent speaker leakage.
$speakers = @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name)
if ($speakers.Count -lt 10) {
    throw "Expected at least 10 VCTK speaker folders under $root; found $($speakers.Count)."
}
$rng = [System.Random]::new($Seed)
for ($i = $speakers.Count - 1; $i -gt 0; $i--) {
    $j = $rng.Next($i + 1)
    $tmp = $speakers[$i]
    $speakers[$i] = $speakers[$j]
    $speakers[$j] = $tmp
}

$nTrain = [int][Math]::Floor($speakers.Count * 0.8)
$nVal = [int][Math]::Floor($speakers.Count * 0.1)
$assignment = @{}
for ($i = 0; $i -lt $speakers.Count; $i++) {
    $split = if ($i -lt $nTrain) { 'train' } elseif ($i -lt ($nTrain + $nVal)) { 'validation' } else { 'test' }
    $assignment[$speakers[$i].Name] = $split
}

$files = foreach ($speaker in ($speakers | Sort-Object Name)) {
    Get-ChildItem -LiteralPath $speaker.FullName -File -Filter '*_mic1.flac' | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            split = $assignment[$speaker.Name]
            speaker = $speaker.Name
            relative_path = [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName).Replace('\', '/')
        }
    }
}
$files | Export-Csv -LiteralPath $outPath -NoTypeInformation -Encoding utf8

$summary = $speakers | Group-Object { $assignment[$_.Name] } | Sort-Object Name | ForEach-Object {
    '{0}: {1} speakers' -f $_.Name, $_.Count
}
Write-Output "Seed: $Seed"
Write-Output "Speakers: $($speakers.Count); files: $($files.Count)"
$summary | ForEach-Object { Write-Output $_ }
Write-Output "Manifest: $outPath"
