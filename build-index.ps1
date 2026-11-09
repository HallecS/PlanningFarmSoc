# Construit index.html (page GitHub Pages) à partir de planning-farm-soc.html (page de l'artefact claude.ai).
# L'artefact ajoute lui-même l'en-tête HTML ; ici on l'écrit : doctype, encodage, affichage mobile.
# À relancer après chaque mise à jour de planning-farm-soc.html, puis commit + push.
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$page = [System.IO.File]::ReadAllText("$root\planning-farm-soc.html", [Text.Encoding]::UTF8)
$head = @'
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#eef1f5" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#121722" media="(prefers-color-scheme: dark)">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="Farm SoC">
<style>[hidden]{display:none!important}body{margin:0}</style>

'@
[System.IO.File]::WriteAllText("$root\index.html", $head + $page, (New-Object System.Text.UTF8Encoding $false))
"index.html : $([math]::Round(($head.Length + $page.Length) / 1KB)) Ko"
