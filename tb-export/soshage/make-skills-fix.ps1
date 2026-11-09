param([string]$Dir)
# Construit skills-fix.json : texte anglais (GameWith) pour les skills que Soshage n'a pas traduits.
# Association par position (attaque de base, skill par défaut, puis chaque rang gauche/droite),
# contrôlée par le coût en NRG et la recharge.
# À lancer sur un skills-all.json SANS corrections (sinon plus rien n'est détecté) : supprimer d'abord skills-fix.gw.json et relancer skills.ps1.
$ErrorActionPreference = "Stop"
$s = Get-Content "$Dir\skills-all.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$en = '\b(the|of|by|and|to|is|on|a|an|gains?|with|for|deals?|DMG)\b'
$cjk = "[{0}-{1}{2}-{3}]" -f [char]0x3040, [char]0x30ff, [char]0x4e00, [char]0x9fff   # (PowerShell 5.1 lit ce script en ANSI)
$foreign = { param($k) ($k.name + ($k.desc -join ' ')) -match $cjk -or (($k.desc -join ' ') -and ($k.desc -join ' ') -notmatch $en) }
$pages = [ordered]@{ "110" = "sp-inanna.html"; "68" = "inanna.html"; "u203" = "finn.html" }
$fix = [ordered]@{}; $report = @()
foreach ($cid in $pages.Keys) {
  $gw = & "$Dir\gamewith-skills.ps1" -Dir $Dir -Page "$Dir\work\gamewith\$($pages[$cid])" | ConvertFrom-Json
  $v = $s.$cid; $pairs = @()
  $pairs += , @($v.basic, $gw.base[0]); $pairs += , @($v.default[0], $gw.base[1])
  foreach ($r in $v.ranks) { $g = @($gw."$($r.rank)"); for ($i = 0; $i -lt $r.skills.Count; $i++) { $pairs += , @($r.skills[$i], $g[$i]) } }
  $fix[$cid] = [ordered]@{}
  foreach ($p in $pairs) {
    $so, $g = $p[0], $p[1]
    if (-not $so -or -not (& $foreign $so)) { continue }
    if (-not $g) { $report += "$cid $($so.id) $($so.name): pas d'équivalent GameWith"; continue }
    $gc = if ($g.cost -eq '-') { 0 } else { [int]$g.cost }; $gd = if ($g.cd -eq '-') { 0 } else { [int]$g.cd }
    $ok = ($gc -eq $so.tp -and $gd -eq $so.cd)
    $report += "$cid $($so.id) $($so.name) -> $($g.name) (coût $($so.tp)/$gc, CD $($so.cd)/$gd)$(if (-not $ok) { '  <<< DIFFÉRENT' })"
    $fix[$cid]["$($so.id)"] = [ordered]@{ name = $g.name; desc = @($g.desc); source = "GameWith" }
  }
}
[System.IO.File]::WriteAllText("$Dir\skills-fix.gw.json", ($fix | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding $false))
$report
