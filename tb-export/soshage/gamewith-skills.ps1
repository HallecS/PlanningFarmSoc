param([string]$Dir, [string]$Page, [string]$CharId)
# Lit une page GameWith (texte anglais officiel) et associe ses skills, dans l'ordre, à ceux de Soshage
# pour un perso dont Soshage n'a pas la traduction. Sortie : objet { idSkill: { name, desc[] } } + contrôle coût/CD.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web
$html = [System.IO.File]::ReadAllText($Page)
$m = [regex]::Match($html, '"articleBody":\s*"((?:[^"\\]|\\.)*)"')
$body = [System.Web.HttpUtility]::HtmlDecode($m.Groups[1].Value)
function Parse([string]$sec) {
  # Entrées « Nom[-][Type] Cost: x / CD: y(Description...) » collées les unes aux autres
  $rx = '-?\[(Basic Attack|Skill|Reaction|Ascension Skill)\] Cost: ([^/]+?) / CD: ([^(]+?)(?=\()'
  $ms = [regex]::Matches($sec, $rx); $out = @()
  for ($i = 0; $i -lt $ms.Count; $i++) {
    $prevEnd = if ($i -eq 0) { 0 } else { $ms[$i - 1].Index + $ms[$i - 1].Length }
    $chunk = $sec.Substring($prevEnd, $ms[$i].Index - $prevEnd)
    # le nom est ce qui suit la dernière fin de phrase de la description précédente
    $cut = [Math]::Max($chunk.LastIndexOf('.'), $chunk.LastIndexOf('SkillRange') + 9)
    $name = $chunk.Substring($cut + 1).Trim()
    if ($i -gt 0) { $out[$i - 1].desc = $chunk.Substring(0, $cut + 1).Trim() }
    $out += [pscustomobject]@{ name = $name; type = $ms[$i].Groups[1].Value; cost = $ms[$i].Groups[2].Value.Trim(); cd = $ms[$i].Groups[3].Value.Trim(); desc = "" }
  }
  if ($out) { $last = $ms[$ms.Count - 1]; $out[-1].desc = $sec.Substring($last.Index + $last.Length).Trim() }
  return $out
}
$res = [ordered]@{}
$base = [regex]::Match($body, "Base Skills(.*?)(SP Skill|Skills That Can Be Learned)").Groups[1].Value
$res["base"] = Parse $base
foreach ($rk in 1, 3, 5, 7, 9, 11) {
  $sec = [regex]::Match($body, "Skills That Can Be Learned at RK$rk(.*?)(Skills That Can Be Learned at RK|Weapons That|$)").Groups[1].Value
  $res["$rk"] = Parse $sec
}
$res | ConvertTo-Json -Depth 5
