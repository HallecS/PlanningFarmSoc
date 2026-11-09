param([string]$Dir, [string]$Src = "keywords-all.json")
# Assemble keywords.js (à côté de la page) :
# window.SOC_KEYWORDS = { kw: {nom: {d:[lignes], i?, k?}}, by: {perso: {nom: déf}}, icons: {"b:x"|"s:x": data URI}, spr: {"▲": data URI, ...} }
$ErrorActionPreference = "Stop"
$data = [System.IO.File]::ReadAllText("$Dir\$Src")
$names = [regex]::Matches($data, '"i":"([bs]):([^"]+)"') | ForEach-Object { $_.Groups[1].Value + ":" + $_.Groups[2].Value } | Sort-Object -Unique
$uri = { param($f) "data:image/webp;base64," + [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($f)) }
$icons = foreach ($n in $names) {
  $f = if ($n.StartsWith("b:")) { "$Dir\kwicons\$($n.Substring(2)).webp" } else { "$Dir\skillicons\$($n.Substring(2)).webp" }
  if (Test-Path $f) { '"' + $n + '":"' + (& $uri $f) + '"' }
}
# Icônes dans le texte : ⊘ = sprite 1 (contrôle), ▲ = sprite 2 (bonus), ▼ = sprite 3 (malus)
$spr = foreach ($p in @(@(0x2298, 1), @(0x25B2, 2), @(0x25BC, 3))) {
  $f = "$Dir\kwicons\icon_sprite_$($p[1]).webp"
  if (-not (Test-Path $f)) { Invoke-WebRequest -UseBasicParsing -Uri "https://img.soshage.com/soc/gl/icon/icon_sprite_$($p[1]).webp" -OutFile $f }
  '"' + [char]$p[0] + '":"' + (& $uri $f) + '"'
}
$js = 'window.SOC_KEYWORDS=' + $data.Substring(0, $data.Length - 1) + ',"icons":{' + (@($icons) -join ",") + '},"spr":{' + ($spr -join ",") + '}};'
[System.IO.File]::WriteAllText("$Dir\..\..\keywords.js", $js, (New-Object System.Text.UTF8Encoding $false))
"keywords.js : $([math]::Round($js.Length / 1KB)) Ko, $(@($icons).Count) icônes"
