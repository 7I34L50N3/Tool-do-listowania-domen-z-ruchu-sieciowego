<#
.SYNOPSIS
    Extracts unique domains from URL lists (e.g. DevTools > Network > Copy all URLs),
    compares them across files and saves the report to a file.
.EXAMPLE
    .\run_tool.ps1 .\Lists\List1.txt .\Lists\List2.txt
.EXAMPLE
    .\run_tool.ps1 .\Lists\*.txt -OutFile .\report.txt
#>

# Parametry wejściowe skryptu
param(
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
    [object[]]$Path,

    [string]$OutFile = (Join-Path $PSScriptRoot "Reports\report_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt")
)

# Pobieranie listy domen z zadanego pliku
function Get-Domains([string]$File) {
    Get-Content -LiteralPath $File |
        ForEach-Object {
            $uri = $null
            if ([uri]::TryCreate($_.Trim(), [UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -in 'http', 'https', 'ws', 'wss') { $uri.Host }
        } |
        Sort-Object -Unique
}

# Formatowanie listy domen
function Format-DomainList([string]$Title, [string[]]$Domains) {
    "==== $Title ($($Domains.Count)) ===="
    $Domains
    ""
}

# Tworzenie nagłówków do grup domen
function Get-GroupTitle([string[]]$Files, [int]$TotalFiles) {
    if ($Files.Count -eq $TotalFiles) { 'Common to all files' }
    elseif ($Files.Count -eq 1) { "Only in $($Files[0])" }
    else { 'In ' + ($Files -join ' + ') }
}


# ***** SKRYPT *****


# 1. Ujednolicenie wektora ścieżek podanych na wejściu skryptu
$Path = $Path | ForEach-Object { $_ }


# 2. Utworzenie tablicy z listami plików oraz zawartymi w nich listami domen
$lists = @(foreach ($file in Get-Item -Path $Path -ErrorAction Stop) {
    [pscustomobject]@{ Name = $file.Name; Domains = @(Get-Domains $file.FullName) }
})


# 3. Odtworzenie struktury: domena <-> powiązane pliki
$filesOf = @{}
for ($i = 0; $i -lt $lists.Count; $i++) {
    foreach ($domain in $lists[$i].Domains) { $filesOf[$domain] += @($i) }
}
$allDomains = @($filesOf.Keys | Sort-Object)


# 4. Tworzenie grup domen (pod względem unikalności ich występowania w plikach wejściowych)
$groups = $allDomains |
    Group-Object { ($filesOf[$_] | ForEach-Object { '{0:D3}' -f $_ }) -join ',' } |
    Sort-Object { $_.Name.Split(',').Count }, Name


# 5. Uformowanie raportu
$report = @(
    foreach ($list in $lists) { Format-DomainList $list.Name $list.Domains }
    foreach ($group in $groups) {
        $files = $lists[$filesOf[$group.Group[0]]].Name
        Format-DomainList (Get-GroupTitle $files $lists.Count) $group.Group
    }
    Format-DomainList 'All domains' $allDomains
)


# 6. Zapis i wyświetlenie raportu
$outDir = Split-Path -Parent $OutFile
if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$report | Set-Content -LiteralPath $OutFile -Encoding UTF8

$report
Write-Host "Report saved to $OutFile"
