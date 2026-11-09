param([string]$Dir)
# Remet à jour la partie « traits » de legendaires.js (à côté de la page) à partir de traits-all.json
# et des icônes de trait (icons/<id perso>.webp). Les persos et sprites ne sont pas touchés.
# Contrôle le résultat avant de remplacer le fichier.
$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$Dir\..\..").Path
$s = [System.IO.File]::ReadAllText("$root\legendaires.js")
$a = $s.IndexOf(',"traits":'); if ($a -lt 0) { throw "bloc traits introuvable" }
$traits = [System.IO.File]::ReadAllText("$Dir\traits-all.json")
$ids = [regex]::Matches($traits, '(?:^\{|,)"([^"]+)":\{"name"') | ForEach-Object { $_.Groups[1].Value }
$icons = foreach ($id in $ids) {
  $f = "$Dir\icons\$id.webp"
  if (Test-Path $f) { '"' + $id + '":"data:image/webp;base64,' + [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($f)) + '"' }
}
$new = $s.Substring(0, $a) + ',"traits":' + $traits + ',"traitIcon":{' + (@($icons) -join ",") + '}};'
Add-Type -AssemblyName System.Web.Extensions
$js = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = 100000000
$o = $js.DeserializeObject($new.Substring($new.IndexOf("=") + 1).TrimEnd(";"))
$msg = "persos $($o['chars'].Count), sprites $($o['sprite'].Count), traits $($o['traits'].Count), icônes de trait $($o['traitIcon'].Count)"
if ($o['chars'].Count -lt 1 -or $o['traits'].Count -ne @($ids).Count) { throw "contrôle échoué : $msg" }
$tmp = "$root\legendaires.tmp.js"
[System.IO.File]::WriteAllText($tmp, $new, (New-Object System.Text.UTF8Encoding $false))
Move-Item $tmp "$root\legendaires.js" -Force
"legendaires.js : $([math]::Round($new.Length / 1KB)) Ko, $msg"
