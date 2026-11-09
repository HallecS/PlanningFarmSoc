param([string]$Dir, [string]$Src = "skills-all.json")
# Assemble skills.js (à côté de la page) : window.SOC_SKILLS = { skills: {...}, icons: { nom: data URI webp } }
$ErrorActionPreference = "Stop"
$data = [System.IO.File]::ReadAllText("$Dir\$Src")
$names = [regex]::Matches($data, '"icon":"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$icons = foreach ($n in $names) {
  $f = "$Dir\skillicons\$n.webp"
  if (Test-Path $f) { '"' + $n + '":"data:image/webp;base64,' + [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($f)) + '"' }
}
# Icône de la Castalia (objet qui débloque le 2e skill d'un choix), recadrée depuis une capture du jeu
if (Test-Path "$Dir\castalia.png") { $icons = @($icons) + ('"__castalia":"data:image/png;base64,' + [Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$Dir\castalia.png")) + '"') }
$js = 'window.SOC_SKILLS={"skills":' + $data + ',"icons":{' + ($icons -join ",") + '}};'
[System.IO.File]::WriteAllText("$Dir\..\..\skills.js", $js, (New-Object System.Text.UTF8Encoding $false))
"skills.js : $([math]::Round($js.Length / 1KB)) Ko, $(@($icons).Count) icônes"
