<#
.SYNOPSIS
    Extracts unique domains from URL lists (e.g. DevTools > Network > Copy all URLs) or HAR files,
    compares them across files and saves the report to a file.
.EXAMPLE
    .\run_tool.ps1 .\Lists\List1.txt .\Lists\List2.har
.EXAMPLE
    .\run_tool.ps1 .\Lists\*.txt -OutFile .\report.txt
.EXAMPLE
    .\run_tool.ps1 .\Lists\*.txt -Subdomains None
#>

# Parametry wejściowe skryptu
param(
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
    [object[]]$Path,

    # All: pełne nazwy hostów, None: sama domena z TLD, liczba: najwyżej tyle poziomów subdomen
    [ValidatePattern('^(All|None|\d+)$')]
    [string]$Subdomains = 'All',

    [string]$OutFile = (Join-Path $PSScriptRoot "Reports\report_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt")
)

# Wczytanie Public Suffix List: zwykłe reguły (com.pl), reguły z gwiazdką (*.ck) i wyjątki (!www.ck)
function Read-SuffixList([string]$File) {
    $list = [pscustomobject]@{
        Rules      = New-Object 'System.Collections.Generic.HashSet[string]'
        Wildcards  = New-Object 'System.Collections.Generic.HashSet[string]'
        Exceptions = New-Object 'System.Collections.Generic.HashSet[string]'
    }
    foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $File -ErrorAction Stop) {
        $rule = $line.Trim()
        if (-not $rule -or $rule.StartsWith('//')) { continue }
        if ($rule.StartsWith('*.')) { [void]$list.Wildcards.Add($rule.Substring(2)) }
        elseif ($rule.StartsWith('!')) { [void]$list.Exceptions.Add($rule.Substring(1)) }
        else { [void]$list.Rules.Add($rule) }
    }
    $list
}

# Skracanie nazwy hosta do domeny z TLD (wg Public Suffix List) i najwyżej $MaxSubdomains poziomów subdomen (-1 = bez limitu)
function Limit-Subdomains([string]$HostName, [int]$MaxSubdomains) {
    # bez limitu, nazwy jednoczłonowe (np. localhost) i adresy IP zostają bez zmian
    if ($MaxSubdomains -lt 0 -or $HostName -notlike '*.*' -or ($HostName -as [ipaddress])) { return $HostName }
    $labels = $HostName.Split('.')
    $last = $labels.Count - 1
    # najdłuższy pasujący sufiks publiczny, od lewej; bez dopasowania sam TLD
    $suffixLength = 1
    for ($i = 0; $i -lt $last; $i++) {
        $candidate = $labels[$i..$last] -join '.'
        if ($script:suffixList.Exceptions.Contains($candidate)) { $suffixLength = $last - $i; break }
        if ($script:suffixList.Rules.Contains($candidate) -or $script:suffixList.Wildcards.Contains(($labels[($i + 1)..$last] -join '.'))) { $suffixLength = $last - $i + 1; break }
    }
    $keep = [Math]::Min($labels.Count, $suffixLength + 1 + $MaxSubdomains)
    $labels[-$keep..-1] -join '.'
}

# Pobieranie listy domen z zadanego pliku
function Get-Domains([string]$File, [int]$MaxSubdomains) {
    # wczytywanie plików HAR, w przeciwnym razie TXT
    $urls = if ($File -like '*.har') {
        (Get-Content -Raw -Encoding UTF8 -LiteralPath $File | ConvertFrom-Json).log.entries.request.url
    } else {
        Get-Content -LiteralPath $File
    }
    $urls |
        ForEach-Object {
            $uri = $null
            if ($_ -and [uri]::TryCreate($_.Trim(), [UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -in 'http', 'https', 'ws', 'wss') { Limit-Subdomains $uri.Host $MaxSubdomains }
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


# 2. Ustawienie limitu subdomen: All -> bez limitu (-1), None -> 0
$maxSubdomains = switch ($Subdomains) { 'All' { -1 } 'None' { 0 } default { [int]$_ } }

# 2a Wczytanie Public Suffix List - potrzebne przy poprawnym skracaniu
if ($maxSubdomains -ge 0) { $suffixList = Read-SuffixList (Join-Path $PSScriptRoot 'public_suffix_list.dat') }


# 3. Utworzenie tablicy z listami plików oraz zawartymi w nich listami domen
$lists = @(foreach ($file in Get-Item -Path $Path -ErrorAction Stop) {
    [pscustomobject]@{ Name = $file.Name; Domains = @(Get-Domains $file.FullName $maxSubdomains) }
})


# 4. Odtworzenie struktury: domena <-> powiązane pliki
$filesOf = @{}
for ($i = 0; $i -lt $lists.Count; $i++) {
    foreach ($domain in $lists[$i].Domains) { $filesOf[$domain] += @($i) }
}
$allDomains = @($filesOf.Keys | Sort-Object)


# 5. Tworzenie grup domen (pod względem unikalności ich występowania w plikach wejściowych)
$groups = $allDomains |
    Group-Object { ($filesOf[$_] | ForEach-Object { '{0:D3}' -f $_ }) -join ',' } |
    Sort-Object { $_.Name.Split(',').Count }, Name


# 6. Uformowanie raportu
$report = @(
    foreach ($list in $lists) { Format-DomainList $list.Name $list.Domains }
    foreach ($group in $groups) {
        $files = $lists[$filesOf[$group.Group[0]]].Name
        Format-DomainList (Get-GroupTitle $files $lists.Count) $group.Group
    }
    Format-DomainList 'All domains' $allDomains
)


# 7. Zapis i wyświetlenie raportu
$outDir = Split-Path -Parent $OutFile
if ($outDir) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$report | Set-Content -LiteralPath $OutFile -Encoding UTF8

$report
Write-Host "Report saved to $OutFile"
