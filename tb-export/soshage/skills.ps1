param([string]$Dir, [string]$Only = "")
# Récupère sur Soshage (version globale) les skills de chaque légendaire listé dans units.txt :
# attaque de base, skill par défaut et arbre de rang (2 choix aux rangs impairs).
# Écrit skills-all.json (clé = id du perso dans legendaires.js) + les icônes dans skillicons/.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Web.Extensions
$json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = 100000000

$legSrc = [System.IO.File]::ReadAllText("$Dir\..\..\legendaires.js")
$leg = $json.DeserializeObject($legSrc.Substring($legSrc.IndexOf("=") + 1).TrimEnd(";"))
$byFace = @{}
foreach ($c in $leg["chars"]) { $k = if ($c["face"]) { $c["face"] } else { $c["icon"] }; $byFace[$k] = $c["id"] }

# Petites icônes du jeu dans le texte : 2 = bonus (▲), 3 = malus (▼), 1 = contrôle (⊘) ; les autres sont retirées
# (caractères construits ici : PowerShell 5.1 lit ce script en ANSI)
$SPR = @{ "1" = [string][char]0x2298; "2" = [string][char]0x25B2; "3" = [string][char]0x25BC }
function Clean([string]$s) {
  $s = [regex]::Replace($s, '<sprite=([123])>', { param($m) $SPR[$m.Groups[1].Value] })
  # Seules les vraies balises de mise en forme sont retirées : un « < » de comparaison (« [Piety]<0 ») doit rester
  return ($s -replace '<sprite=\d+>', '' -replace '<(?=/?(style|color|size|sprite|i|b|u|link|align|font)\b)[^>]*>', '').Trim()
}
# Renvois du jeu vers le texte d'un autre buff : « {buff/desc/9941} », « {buff/name/7721} »
# → texte récupéré sur l'API Soshage (/api/proxy/en/buff/<n°>, mis en cache dans pages/buff-<n°>.json)
$BUFF = @{}
function BuffOf([string]$id) {
  if (-not $BUFF.ContainsKey($id)) {
    $f = "$Dir\pages\buff-$id.json"
    try {
      if (-not (Test-Path $f)) { Invoke-WebRequest -UseBasicParsing -Uri "https://soshage.com/soc/api/proxy/en/buff/$id" -OutFile $f }
      $BUFF[$id] = $json.DeserializeObject([System.IO.File]::ReadAllText($f, [Text.Encoding]::UTF8))
    } catch { $BUFF[$id] = $null }
  }
  return $BUFF[$id]
}
function Resolve([string]$s) {
  for ($n = 0; $n -lt 3 -and $s -match '\{buff/(name|desc)/\d+\}'; $n++) {
    $s = [regex]::Replace($s, '\{buff/(name|desc)/(\d+)\}', { param($m) $b = BuffOf $m.Groups[2].Value; if ($b) { [string]$b[$m.Groups[1].Value] } else { "" } })
  }
  return $s
}
function DescLines([string]$d) { return @(((Resolve $d) -split '<sprite=10>|\n') | ForEach-Object { Clean $_ } | Where-Object { $_ -ne "" }) }
# Objet JSON qui commence à l'index $j (accolades équilibrées, chaînes ignorées)
function ObjAt([string]$r, [int]$j) {
  $depth = 0; $k = $j
  for (; $k -lt $r.Length; $k++) {
    $ch = $r[$k]
    if ($ch -eq '{') { $depth++ } elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { break } }
    elseif ($ch -eq '"') { $k++; while ($k -lt $r.Length -and $r[$k] -ne '"') { if ($r[$k] -eq '\') { $k++ }; $k++ } }
  }
  return $json.DeserializeObject($r.Substring($j, $k - $j + 1))
}
# Fiche d'un skill à partir de son id (première définition complète trouvée)
function SkillOf([string]$r, [int]$id) {
  foreach ($m in [regex]::Matches($r, '\{"id":' + $id + ',"name":"')) {
    $o = ObjAt $r $m.Index
    if ($o.ContainsKey("desc") -and $o.ContainsKey("icon") -and $o.ContainsKey("cooldown")) {
      # Texte long : Next.js le met à part (« $22 » renvoie au bloc « 22:T<taille hexa en octets>,<texte> »)
      if ($o["desc"] -match '^\$([0-9a-f]+)$') {
        # (le bloc peut suivre directement un autre bloc texte, sans retour à la ligne)
        $ref = [regex]::Match($r, '(?<![0-9a-f])' + $Matches[1] + ':T([0-9a-f]+),')
        if ($ref.Success) {
          $n = [Convert]::ToInt32($ref.Groups[1].Value, 16); $start = $ref.Index + $ref.Length; $k = $start; $bytes = 0
          while ($k -lt $r.Length -and $bytes -lt $n) { $bytes += [Text.Encoding]::UTF8.GetByteCount([string]$r[$k]); $k++ }
          $o["desc"] = $r.Substring($start, $k - $start)
        }
      }
      $lines = @(DescLines $o["desc"])   # @() : une seule ligne doit rester une liste
      # Description vide : une autre entrée du même nom sur la page l'a parfois (variante du skill)
      if (-not $lines.Count -and $o["name"]) {
        foreach ($m2 in [regex]::Matches($r, '\{"id":\d+,"name":"' + [regex]::Escape($o["name"]) + '","desc":"[^"$]')) {
          $alt = ObjAt $r $m2.Index; $lines = @(DescLines $alt["desc"]); if ($lines.Count) { break }
        }
      }
      return [ordered]@{ id = $id; name = (Clean $o["name"]); icon = $o["icon"]; kind = [int]$o["class_type"]; skillType = [int]$o["skill_type"];
        tp = [int]$o["tp"]; cd = [int]$o["cooldown"]; range = @([int]$o["range_min"], [int]$o["range_max"]); desc = $lines }
    }
  }
  return $null
}

New-Item -ItemType Directory -Force "$Dir\pages" | Out-Null
New-Item -ItemType Directory -Force "$Dir\skillicons" | Out-Null
New-Item -ItemType Directory -Force "$Dir\kwicons" | Out-Null
$out = [ordered]@{}; $report = @()
# Mots-clés (entre crochets dans les textes) : définition commune + celles propres à un perso si elles diffèrent
$kw = [ordered]@{}; $kwBy = [ordered]@{}
function KeywordsOf([string]$r, [string]$cid) {
  foreach ($m in [regex]::Matches($r, '"keyword":\{"id":')) {
    $o = ObjAt $r ($m.Index + 10)
    $name = Clean (Resolve $o["name"]); if (-not $name) { continue }
    $src = if ($o["desc"]) { $o } elseif ($o["buff"] -and $o["buff"]["desc"]) { $o["buff"] } elseif ($o["skill"] -and $o["skill"]["desc"]) { $o["skill"] } else { $null }
    if (-not $src) { continue }
    $d = $src["desc"]
    if ($d -match '^\$([0-9a-f]+)$') { continue }   # texte déporté : rare pour un mot-clé, ignoré
    $def = [ordered]@{ d = @(DescLines $d) }
    if ($o["buff"] -and $o["buff"]["icon"]) { $def.i = "b:" + $o["buff"]["icon"] }
    elseif ($o["skill"] -and $o["skill"]["icon"] -and -not $o["desc"]) { $def.i = "s:" + $o["skill"]["icon"]; $def.k = "skill" }
    if (-not $script:kw.Contains($name)) { $script:kw[$name] = $def }
    elseif (($script:kw[$name].d -join "|") -ne ($def.d -join "|")) {
      if (-not $script:kwBy.Contains($cid)) { $script:kwBy[$cid] = [ordered]@{} }
      $script:kwBy[$cid][$name] = $def
    }
  }
}
$units = ([System.IO.File]::ReadAllText("$Dir\units.txt").Trim() -split ",") | ForEach-Object { $p = $_ -split ":"; [pscustomobject]@{ id = $p[0]; face = $p[1] } }
if ($Only) { $units = @($units | Where-Object { ($Only -split ",") -contains $_.id }) }
# Persos traduits à la main (tw-translations/<n°>.json) : données lues sur la page zh-tw, textes remplacés après coup
$twTr = @{}
foreach ($f in Get-ChildItem "$Dir\tw-translations\*.json" -ErrorAction SilentlyContinue) { $twTr[$f.BaseName] = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
# Télécharge une image Soshage : version globale, sinon version zh-tw (persos pas encore sortis en global)
function GetImg([string]$sub, [string]$name, [string]$file) {
  foreach ($srv in "gl", "tw") { try { Invoke-WebRequest -UseBasicParsing -Uri "https://img.soshage.com/soc/$srv/$sub/$name.webp" -OutFile $file; return $true } catch {} }
  return $false
}
foreach ($u in $units) {
  $cid = $byFace[$u.face]
  if (-not $cid) { $report += "$($u.id) $($u.face): perso introuvable"; continue }
  try {
    $isTw = $twTr.ContainsKey($u.id)
    $page = if ($isTw) { "$Dir\pages\tw-$($u.id).html" } else { "$Dir\pages\$($u.id).html" }
    $lng = if ($isTw) { "zh-tw" } else { "en" }
    if (-not (Test-Path $page)) { Invoke-WebRequest -UseBasicParsing -Uri "https://soshage.com/soc/$lng/unit/$($u.id)" -OutFile $page; Start-Sleep -Milliseconds 250 }
    $html = [System.IO.File]::ReadAllText($page)
    $raw = New-Object System.Text.StringBuilder
    foreach ($m in [regex]::Matches($html, 'self\.__next_f\.push\((\[[\s\S]*?\])\)</script>')) {
      try { $a = $json.DeserializeObject($m.Groups[1].Value); if ($a.Count -gt 1 -and $a[1] -is [string]) { [void]$raw.Append($a[1]) } } catch {}
    }
    $r = $raw.ToString()
    $basic = [regex]::Match($r, '"basic_skill":\{"unit_id":\d+,"skill_id":(\d+)')
    $def = [regex]::Match($r, '"default_skills":"([\d,]*)"')
    $ranks = @()
    foreach ($m in [regex]::Matches($r, '"rank":(\d+),"money"[^}]*?"skill1_id":(\d+),"is_skill1_share":\w+,"skill2_id":(\d+),"is_skill2_share":\w+,"enhance_skill1_id":(\d+),"enhance_skill2_id":(\d+)')) {
      $ids = @([int]$m.Groups[2].Value, [int]$m.Groups[3].Value) | Where-Object { $_ -gt 0 }
      $enh = @([int]$m.Groups[4].Value, [int]$m.Groups[5].Value) | Where-Object { $_ -gt 0 }
      if ($ids) {
        $rk = [ordered]@{ rank = [int]$m.Groups[1].Value; skills = @($ids | ForEach-Object { SkillOf $r $_ } | Where-Object { $_ }) }
        # Version améliorée du skill (certains persos n'ont pas de choix mais une amélioration par rang)
        if ($enh) { $rk.enh = @($enh | ForEach-Object { SkillOf $r $_ } | Where-Object { $_ }) }
        $ranks += $rk
      }
    }
    $ranks = @($ranks | Sort-Object { $_.rank })
    $o = [ordered]@{
      basic = if ($basic.Success) { SkillOf $r ([int]$basic.Groups[1].Value) } else { $null }
      default = @(($def.Groups[1].Value -split ",") | Where-Object { $_ } | ForEach-Object { SkillOf $r ([int]$_) } | Where-Object { $_ })
      ranks = $ranks
    }
    $out[$cid] = $o
    if (-not $isTw) { KeywordsOf $r $cid }   # (perso traduit : mots-clés repris de sa traduction)
    $all = @($o.basic) + $o.default + @($ranks | ForEach-Object { $_.skills; $_.enh })
    foreach ($s in $all) {
      if ($s -and $s.icon -and -not (Test-Path "$Dir\skillicons\$($s.icon).webp")) {
        if (-not (GetImg "skill" $s.icon "$Dir\skillicons\$($s.icon).webp")) { $report += "$cid : icône $($s.icon) absente" }
      }
    }
    $report += "$($u.id) $cid : base $([bool]$o.basic), défaut $($o.default.Count), rangs $(($ranks | ForEach-Object { "$($_.rank):$($_.skills.Count)" }) -join ' ')"
  } catch { $report += "$($u.id) $cid : ERREUR $($_.Exception.Message)" }
}
# Corrections : texte anglais pour les skills que Soshage n'a pas traduits
# (skills-fix.gw.json = GameWith, via make-skills-fix.ps1 ; skills-fix.manual.json = traductions)
# Appliquées AVANT les persos traduits ci-dessous, qui reprennent ces textes corrigés quand un skill est partagé.
foreach ($ff in Get-ChildItem "$Dir\skills-fix*.json") {
  $fix = Get-Content $ff.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($c in $fix.PSObject.Properties) {
    $o = $out[$c.Name]; if (-not $o) { continue }
    $all = @($o.basic) + $o.default + @($o.ranks | ForEach-Object { $_.skills; $_.enh })
    foreach ($f in $c.Value.PSObject.Properties) {
      foreach ($sk in @($all | Where-Object { $_ -and "$($_.id)" -eq $f.Name })) { $sk.name = $f.Value.name; $sk.desc = @($f.Value.desc); $sk.src = $f.Value.source }
    }
  }
}
# Persos traduits à la main : texte anglais officiel quand le skill existe chez un autre perso (même id),
# sinon la traduction ; leurs mots-clés traduits deviennent des définitions propres au perso.
$cjkRx = "[{0}-{1}{2}-{3}]" -f [char]0x3040, [char]0x30ff, [char]0x4e00, [char]0x9fff
$enById = @{}
foreach ($u in $units) { if ($twTr.ContainsKey($u.id)) { continue }; $o = $out[$byFace[$u.face]]; if (-not $o) { continue }
  foreach ($s in @($o.basic) + $o.default + @($o.ranks | ForEach-Object { $_.skills; $_.enh })) {
    if ($s -and -not (($s.name + ($s.desc -join '')) -match $cjkRx)) { $enById["$($s.id)"] = $s } } }   # (jamais un texte resté en chinois)
foreach ($n in $twTr.Keys) {
  $tr = $twTr[$n]; $cid = $tr.charId; $o = $out[$cid]; if (-not $o) { continue }
  foreach ($s in @($o.basic) + $o.default + @($o.ranks | ForEach-Object { $_.skills; $_.enh })) {
    if (-not $s) { continue }
    $e = $enById["$($s.id)"]; $t = $tr.skills."$($s.id)"
    if ($e) { $s.name = $e.name; $s.desc = @($e.desc) }
    elseif ($t) { $s.name = $t.name; $s.desc = @($t.desc); $s.src = "traduction (Soshage zh-tw)" }
    else { $report += "$cid : skill $($s.id) $($s.name) sans traduction" }
  }
  if (-not $kwBy.Contains($cid)) { $kwBy[$cid] = [ordered]@{} }
  foreach ($k in $tr.keywords.PSObject.Properties) {
    $def = [ordered]@{ d = @($k.Value.d) }; if ($k.Value.i) { $def.i = $k.Value.i }; if ($k.Value.k) { $def.k = $k.Value.k }
    $kwBy[$cid][$k.Name] = $def
  }
}
$file = if ($Only) { "$Dir\skills-test.json" } else { "$Dir\skills-all.json" }
[System.IO.File]::WriteAllText($file, ($out | ConvertTo-Json -Depth 8 -Compress), (New-Object System.Text.UTF8Encoding $false))
# Complément : liste complète des mots-clés de Soshage (/soc/api/proxy/en/skillkeyword), pour les noms absents des pages persos
$kwList = "$Dir\pages\skillkeyword.json"
if (-not (Test-Path $kwList)) { Invoke-WebRequest -UseBasicParsing -Uri "https://soshage.com/soc/api/proxy/en/skillkeyword" -OutFile $kwList }
foreach ($o in $json.DeserializeObject([System.IO.File]::ReadAllText($kwList, [Text.Encoding]::UTF8))) {
  $name = Clean $o["name"]
  if ($name -and $o["desc"] -and -not $kw.Contains($name)) { $kw[$name] = [ordered]@{ d = @(DescLines $o["desc"]) } }
}
# Dernier recours : termes entre crochets (skills, traits, définitions) encore sans définition,
# cherchés par nom dans la liste complète des buffs (/api/proxy/en/buff, avec texte anglais)
$buffList = "$Dir\pages\buff-all.json"
if (-not (Test-Path $buffList)) { Invoke-WebRequest -UseBasicParsing -Uri "https://soshage.com/soc/api/proxy/en/buff" -OutFile $buffList }
$buffByName = @{}
foreach ($b in $json.DeserializeObject([System.IO.File]::ReadAllText($buffList, [Text.Encoding]::UTF8))) {
  $n = Clean (Resolve $b["name"]); $dd = Resolve $b["desc"]
  if ($n -and $dd -and $dd -match '[a-zA-Z]{3}' -and -not $buffByName.ContainsKey($n.ToLower())) { $buffByName[$n.ToLower()] = $b }
}
$texts = ($out | ConvertTo-Json -Depth 8 -Compress) + [System.IO.File]::ReadAllText("$Dir\traits-all.json") + ($kw | ConvertTo-Json -Depth 6 -Compress)
$known = @{}; foreach ($k in $kw.Keys) { $known[$k.ToLower()] = 1 }
foreach ($m in [regex]::Matches($texts, '\[([^\[\]"]+)\]')) {
  $n = $m.Groups[1].Value.Trim(); $l = $n.ToLower()
  if ($known[$l] -or $known[$l -replace 's$', '']) { continue }
  $b = $buffByName[$l]; if (-not $b) { continue }
  $def = [ordered]@{ d = @(DescLines $b["desc"]) }; if ($b["icon"]) { $def.i = "b:" + $b["icon"] }
  $kw[$n] = $def; $known[$l] = 1
}
# Icônes des mots-clés (buffs : dossier buff ; skills liés : dossier skill)
foreach ($def in @($kw.Values) + @($kwBy.Values | ForEach-Object { $_.Values })) {
  if (-not $def.i) { continue }
  $n = $def.i.Substring(2); $sub = if ($def.i.StartsWith("b:")) { "buff" } else { "skill" }
  $f = if ($sub -eq "buff") { "$Dir\kwicons\$n.webp" } else { "$Dir\skillicons\$n.webp" }
  if (-not (Test-Path $f)) { if (-not (GetImg $sub $n $f)) { $def.Remove("i") } }
}
$kfile = if ($Only) { "$Dir\keywords-test.json" } else { "$Dir\keywords-all.json" }
[System.IO.File]::WriteAllText($kfile, ([ordered]@{ kw = $kw; by = $kwBy } | ConvertTo-Json -Depth 8 -Compress), (New-Object System.Text.UTF8Encoding $false))
"keywords: $($kw.Count) communs, $(@($kwBy.Keys).Count) persos avec définitions propres"
"skills: $($out.Count) / $($units.Count)"
$report
