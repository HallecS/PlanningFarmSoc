param([string]$Dir, [string]$Unit)
# Persos pas encore traduits sur Soshage EN : extrait de la page zh-tw (pages/tw-<n°>.html) le trait, les skills
# et les mots-clés, en indiquant pour chaque skill si un texte anglais existe déjà (même id chez un autre perso).
# Sortie : work/tw-<n°>.json, base de la traduction (tw-translations/<n°>.json).
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web.Extensions
$json = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $json.MaxJsonLength = 100000000
$html = [System.IO.File]::ReadAllText("$Dir\pages\tw-$Unit.html"); $raw = New-Object System.Text.StringBuilder
foreach ($m in [regex]::Matches($html, 'self\.__next_f\.push\((\[[\s\S]*?\])\)</script>')) {
  try { $a = $json.DeserializeObject($m.Groups[1].Value); if ($a.Count -gt 1 -and $a[1] -is [string]) { [void]$raw.Append($a[1]) } } catch {}
}
$r = $raw.ToString()
function ObjAt([string]$r, [int]$j) {
  $depth = 0; $k = $j
  for (; $k -lt $r.Length; $k++) { $ch = $r[$k]
    if ($ch -eq '{') { $depth++ } elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { break } }
    elseif ($ch -eq '"') { $k++; while ($k -lt $r.Length -and $r[$k] -ne '"') { if ($r[$k] -eq '\') { $k++ }; $k++ } } }
  return $json.DeserializeObject($r.Substring($j, $k - $j + 1))
}
function SkillRaw([int]$id) {
  foreach ($m in [regex]::Matches($r, '\{"id":' + $id + ',"name":"')) { $o = ObjAt $r $m.Index
    if ($o.ContainsKey("desc") -and $o.ContainsKey("cooldown") -and $o["desc"]) { return $o } }
  foreach ($m in [regex]::Matches($r, '\{"id":' + $id + ',"name":"')) { $o = ObjAt $r $m.Index; if ($o.ContainsKey("cooldown")) { return $o } }
  return $null
}
# Textes anglais connus, par id de skill (tous persos confondus)
$en = @{}
$all = $json.DeserializeObject([System.IO.File]::ReadAllText("$Dir\skills-all.json", [Text.Encoding]::UTF8))
foreach ($c in $all.Values) { foreach ($s in @($c["basic"]) + @($c["default"]) + @($c["ranks"] | ForEach-Object { $_["skills"] })) {
  if ($s -and ($s["name"] -match '^[\x20-\x7E]+$')) { $en["$($s["id"])"] = $s } } }
$out = [ordered]@{ unit = $Unit; skills = @(); trait = $null; keywords = [ordered]@{} }
$ids = @()
$b = [regex]::Match($r, '"basic_skill":\{"unit_id":\d+,"skill_id":(\d+)'); if ($b.Success) { $ids += , @("basic", [int]$b.Groups[1].Value) }
foreach ($x in ([regex]::Match($r, '"default_skills":"([\d,]*)"').Groups[1].Value -split ',' | Where-Object { $_ })) { $ids += , @("default", [int]$x) }
foreach ($m in [regex]::Matches($r, '"rank":(\d+),"money"[^}]*?"skill1_id":(\d+),"is_skill1_share":\w+,"skill2_id":(\d+),"is_skill2_share":\w+,"enhance_skill1_id":(\d+),"enhance_skill2_id":(\d+)')) {
  foreach ($x in @($m.Groups[2].Value, $m.Groups[3].Value) | Where-Object { $_ -ne '0' }) { $ids += , @("rk$($m.Groups[1].Value)", [int]$x) }
  foreach ($x in @($m.Groups[4].Value, $m.Groups[5].Value) | Where-Object { $_ -ne '0' }) { $ids += , @("rk$($m.Groups[1].Value)-enh", [int]$x) } }
foreach ($p in $ids) {
  $o = SkillRaw $p[1]
  $out.skills += [ordered]@{ slot = $p[0]; id = $p[1]; known = $en.ContainsKey("$($p[1])"); name = $o["name"]; desc = $o["desc"]; icon = $o["icon"]; kind = $o["class_type"]; tp = $o["tp"]; cd = $o["cooldown"]; range = @($o["range_min"], $o["range_max"]) }
}
$i = $r.IndexOf('"personality":{'); if ($i -ge 0) { $p = ObjAt $r ($r.IndexOf('{', $i))
  $out.trait = [ordered]@{ name = $p["name"]; icon = $p["icon"]; skills = @($p["skills"] | ForEach-Object { [ordered]@{ star = $_["star"]; group = $_["skill_group_id"]; desc = $(if ($_["desc"]) { $_["desc"] } else { $_["skill"]["desc"] }) } }) } }
foreach ($m in [regex]::Matches($r, '"keyword":\{"id":')) { $o = ObjAt $r ($m.Index + 10)
  $d = if ($o["desc"]) { $o["desc"] } elseif ($o["buff"]) { $o["buff"]["desc"] } elseif ($o["skill"]) { $o["skill"]["desc"] } else { "" }
  if (-not $out.keywords.Contains($o["name"])) { $out.keywords[$o["name"]] = [ordered]@{ id = $o["id"]; desc = $d; icon = $(if ($o["buff"]) { $o["buff"]["icon"] } else { $null }) } } }
[System.IO.File]::WriteAllText("$Dir\work\tw-$Unit.json", ($out | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding $false))
"skills: $($out.skills.Count) (déjà en anglais : $(@($out.skills | Where-Object { $_.known }).Count)) ; trait : $($out.trait.name) ; mots-clés : $($out.keywords.Count)"
