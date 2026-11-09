param([string]$Dir)
# Récupère sur Soshage (version globale) le trait par étoile de chaque légendaire listé dans units.txt
# et l'écrit dans traits-all.json (clé = id du perso dans legendaires.js) + les icônes de trait.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Web.Extensions
$json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = 100000000

# face -> id du perso dans legendaires.js
$legSrc = [System.IO.File]::ReadAllText("$Dir\..\..\legendaires.js")
$leg = $json.DeserializeObject($legSrc.Substring($legSrc.IndexOf("=") + 1).TrimEnd(";"))
$byFace = @{}
foreach ($c in $leg["chars"]) { $k = if ($c["face"]) { $c["face"] } else { $c["icon"] }; $byFace[$k] = $c["id"] }

# Icônes du jeu dans le texte : 2 = bonus (▲), 3 = malus (▼), 1 = contrôle (⊘) (caractères construits : script lu en ANSI)
$SPR = @{ "1" = [string][char]0x2298; "2" = [string][char]0x25B2; "3" = [string][char]0x25BC }
function Clean([string]$s) {
  $s = [regex]::Replace($s, '<sprite=([123])>', { param($m) $SPR[$m.Groups[1].Value] })
  $s = $s -replace '<style=[^>]*>', '' -replace '</style>', '' -replace '<[^>]+>', ''
  return $s.Trim()
}
function Lines([string]$desc) {
  # <sprite=10> = puce de début de ligne ; les autres sprites (0-3) sont des icônes dans le texte
  return @(($desc -split '<sprite=10>|\n') | ForEach-Object { Clean $_ } | Where-Object { $_ -ne "" })
}

New-Item -ItemType Directory -Force "$Dir\pages" | Out-Null
New-Item -ItemType Directory -Force "$Dir\icons" | Out-Null
$out = [ordered]@{}; $report = @()
$units = ([System.IO.File]::ReadAllText("$Dir\units.txt").Trim() -split ",") | ForEach-Object { $p = $_ -split ":"; [pscustomobject]@{ id = $p[0]; face = $p[1] } }
foreach ($u in $units) {
  $cid = $byFace[$u.face]
  if (-not $cid) { $report += "$($u.id) $($u.face): perso introuvable dans legendaires.js"; continue }
  try {
    $page = "$Dir\pages\$($u.id).html"
    if (-not (Test-Path $page)) { Invoke-WebRequest -UseBasicParsing -Uri "https://soshage.com/soc/en/unit/$($u.id)" -OutFile $page; Start-Sleep -Milliseconds 250 }
    $html = [System.IO.File]::ReadAllText($page)
    $raw = New-Object System.Text.StringBuilder
    foreach ($m in [regex]::Matches($html, 'self\.__next_f\.push\((\[[\s\S]*?\])\)</script>')) {
      try { $a = $json.DeserializeObject($m.Groups[1].Value); if ($a.Count -gt 1 -and $a[1] -is [string]) { [void]$raw.Append($a[1]) } } catch {}
    }
    $r = $raw.ToString()
    $i = $r.IndexOf('"personality":{')
    if ($i -lt 0) { $report += "$($u.id) $cid : pas de trait"; continue }
    $j = $r.IndexOf("{", $i); $depth = 0; $k = $j
    for (; $k -lt $r.Length; $k++) {
      $ch = $r[$k]
      if ($ch -eq '{') { $depth++ } elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { break } }
      elseif ($ch -eq '"') { $k++; while ($k -lt $r.Length -and $r[$k] -ne '"') { if ($r[$k] -eq '\') { $k++ }; $k++ } }
    }
    $p = $json.DeserializeObject($r.Substring($j, $k - $j + 1))
    # Deux formats sur Soshage :
    #  - groupe 1 = lignes fixes, chacune débloquée à son étoile (anciens persos : 1 ligne par étoile) ;
    #  - groupe 2 = version complète des lignes « évolutives » pour chaque étoile (persos récents).
    # On produit : base = lignes du groupe 1 à 1★, levels[n] = groupe 2 à n★ (ou dernier niveau connu)
    #              + lignes du groupe 1 débloquées entre 2★ et n★.
    $fixed = @(); $evo = @{}
    foreach ($s in $p["skills"]) {
      $d = if ($s["desc"]) { $s["desc"] } else { $s["skill"]["desc"] }
      if ([int]$s["skill_group_id"] -eq 1) { $fixed += [pscustomobject]@{ star = [int]$s["star"]; lines = (Lines $d) } }
      else { $evo[[int]$s["star"]] = Lines $d }
    }
    $base = @($fixed | Where-Object { $_.star -le 1 } | ForEach-Object { $_.lines })
    $levels = [ordered]@{}; $lastEvo = @()
    foreach ($n in 1..5) {
      if ($evo.ContainsKey($n)) { $lastEvo = $evo[$n] }
      $levels["$n"] = @($lastEvo) + @($fixed | Where-Object { $_.star -gt 1 -and $_.star -le $n } | Sort-Object star | ForEach-Object { $_.lines })
    }
    $out[$cid] = [ordered]@{ name = (Clean $p["name"]); icon = $p["icon"]; source = "soshage $($u.id)"; base = $base; levels = $levels }
    if ($p["icon"] -and -not (Test-Path "$Dir\icons\$cid.webp")) {
      Invoke-WebRequest -UseBasicParsing -Uri "https://img.soshage.com/soc/gl/unitpersonality/$($p["icon"]).webp" -OutFile "$Dir\icons\$cid.webp"
    }
    $report += "$($u.id) $cid : $($p["name"]) - base $($base.Count), niveaux $($levels.Keys -join '')"
  } catch { $report += "$($u.id) $cid : ERREUR $($_.Exception.Message)" }
}
# Corrections manuelles (traits mal traduits sur Soshage, saisis depuis le jeu)
if (Test-Path "$Dir\traits-fix.json") {
  $fix = Get-Content "$Dir\traits-fix.json" -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($f in $fix.PSObject.Properties) {
    $icon = if ($out[$f.Name]) { $out[$f.Name].icon } else { $null }
    $out[$f.Name] = [ordered]@{ name = $f.Value.name; icon = $icon; source = "jeu (correction manuelle)"; base = $f.Value.base; levels = $f.Value.levels }
  }
}
# Persos traduits à la main depuis la page zh-tw (tw-translations/<n°>.json) : trait traduit + icône (globale, sinon zh-tw)
foreach ($f in Get-ChildItem "$Dir\tw-translations\*.json" -ErrorAction SilentlyContinue) {
  $tr = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $tr.trait) { continue }
  $out[$tr.charId] = [ordered]@{ name = $tr.trait.name; icon = $tr.trait.icon; source = "traduction (Soshage zh-tw $($f.BaseName))"; base = @($tr.trait.base); levels = $tr.trait.levels }
  $ico = "$Dir\icons\$($tr.charId).webp"
  if ($tr.trait.icon -and -not (Test-Path $ico)) {
    foreach ($srv in "gl", "tw") { try { Invoke-WebRequest -UseBasicParsing -Uri "https://img.soshage.com/soc/$srv/unitpersonality/$($tr.trait.icon).webp" -OutFile $ico; break } catch {} }
  }
}
[System.IO.File]::WriteAllText("$Dir\traits-all.json", ($out | ConvertTo-Json -Depth 8 -Compress), (New-Object System.Text.UTF8Encoding $false))
"traits: $($out.Count) / $($units.Count)"
$report | Where-Object { $_ -match 'ERREUR|pas de trait|introuvable|niveaux 1234$|niveaux $' }
"--- exemples"
$report | Where-Object { $_ -match '^(204|219|220|221|222|223) ' }
