param([string]$Icons, [string]$CharsDir, [string]$Out)
# Extrait du fichier icons.js du Team Builder les portraits et sprites des persos légendaires
$src = [System.IO.File]::ReadAllText($Icons)
$groups = @("face", "rarity", "sprite", "tag", "type")
$pos = @{}
foreach ($g in $groups) { $pos[$g] = $src.IndexOf('"' + $g + '":{') }
$sorted = $groups | Sort-Object { $pos[$_] }
function Get-Section($g) {
  $start = $pos[$g]
  $next = ($sorted | Where-Object { $pos[$_] -gt $start } | ForEach-Object { $pos[$_] } | Measure-Object -Minimum).Minimum
  if (-not $next) { $next = $src.Length }
  return $src.Substring($start, $next - $start)
}
$sections = @{}
foreach ($g in $groups) { $sections[$g] = Get-Section $g }
function Get-Icon($section, $key) {
  $m = [regex]::Match($section, '"' + [regex]::Escape($key) + '":"(data:image/[a-z]+;base64,[^"]+)"')
  if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
$chars = Get-ChildItem $CharsDir -Filter *.json | ForEach-Object {
  $j = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  $d = if ($j.data) { $j.data } else { $j }
  [pscustomobject]@{ id = $_.BaseName; name = $d.name; class = $d.class; type = $d.type; tags = @($d.tags); icon = $d.icon }
} | Sort-Object name
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("window.SOC_LEGENDARIES={`"chars`":")
[void]$sb.Append(($chars | ConvertTo-Json -Compress -Depth 4))
$missing = @()
foreach ($g in @("sprite")) {
  [void]$sb.Append(",`"$g`":{")
  $first = $true
  foreach ($c in $chars) {
    $v = Get-Icon $sections[$g] $c.icon
    if (-not $v) { $missing += "$g/$($c.name)"; continue }
    if (-not $first) { [void]$sb.Append(",") }
    [void]$sb.Append("`"$($c.icon)`":`"$v`"")
    $first = $false
  }
  [void]$sb.Append("}")
}
[void]$sb.Append("};")
[System.IO.File]::WriteAllText($Out, $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
"chars: $($chars.Count)"
"missing: $($missing -join ', ')"
"size: $((Get-Item $Out).Length) bytes"
