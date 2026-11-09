param([string]$Dir, [string]$Unit)
# Liste compacte de ce qu'il reste à traduire pour un perso zh-tw (à partir de work/tw-<n°>.json) :
# skills sans texte anglais connu, trait, mots-clés avec leur nom anglais officiel quand il existe (même id).
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Web.Extensions
$json = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $json.MaxJsonLength = 100000000
$SPR = @{ "1" = [string][char]0x2298; "2" = [string][char]0x25B2; "3" = [string][char]0x25BC }
function C([string]$s) { $s = [regex]::Replace($s, '<sprite=([123])>', { param($m) $SPR[$m.Groups[1].Value] }); ($s -replace '<sprite=10>', '* ' -replace '<[^>]+>', '' -replace '\n', ' ').Trim() }
$tw = $json.DeserializeObject([System.IO.File]::ReadAllText("$Dir\work\tw-$Unit.json", [Text.Encoding]::UTF8))
$kwEn = @{}; foreach ($o in $json.DeserializeObject([System.IO.File]::ReadAllText("$Dir\pages\skillkeyword.json", [Text.Encoding]::UTF8))) { $kwEn["$($o['id'])"] = $o }
"== SKILLS"
foreach ($s in $tw["skills"]) { if ($s["known"]) { "  [$($s['slot'])] $($s['id']) (déjà EN)"; continue }
  "  [$($s['slot'])] $($s['id']) $($s['name']) | kind $($s['kind']) NRG $($s['tp']) CD $($s['cd']) :: $(C $s['desc'])" }
"== TRAIT $($tw['trait']['name'])"
foreach ($t in $tw["trait"]["skills"]) { "  ★$($t['star']) g$($t['group']) :: $(C $t['desc'])" }
"== MOTS-CLÉS"
foreach ($k in $tw["keywords"].Keys) { $v = $tw["keywords"][$k]; $e = $kwEn["$($v['id'])"]
  if ($e) { "  $(C $k) = $(C $e['name'])" } else { "  $(C $k) [id $($v['id']), icône $($v['icon'])] :: $(C $v['desc'])" } }
