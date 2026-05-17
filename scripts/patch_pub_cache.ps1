# Reapplique les patches sur flutter_media_metadata apres flutter pub cache repair.
# Lancer depuis la racine du projet : .\scripts\patch_pub_cache.ps1

$base = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\flutter_media_metadata-1.0.0+1\android"

if (-not (Test-Path $base)) {
    Write-Error "flutter_media_metadata introuvable dans le cache pub. Lance 'flutter pub get' d'abord."
    exit 1
}

# Patch 1 : compileSdkVersion 29 -> 36
$gradle = "$base\build.gradle"
$content = Get-Content $gradle -Raw
if ($content -match 'compileSdkVersion 29') {
    $content = $content -replace 'compileSdkVersion 29', 'compileSdkVersion 36'
    Set-Content $gradle $content -NoNewline
    Write-Host "[OK] compileSdkVersion patche : 29 -> 36"
} else {
    Write-Host "[SKIP] compileSdkVersion deja patche."
}

# Patch 2 : retriever.release() -> try/catch IOException
$java = "$base\src\main\java\com\alexmercerind\flutter_media_metadata\FlutterMediaMetadataPlugin.java"
$content = Get-Content $java -Raw
if ($content -match 'retriever\.release\(\);' -and $content -notmatch 'catch.*IOException') {
    $content = $content -replace 'import java\.util\.HashMap;', "import java.io.IOException;`nimport java.util.HashMap;"
    $content = $content -replace '          retriever\.release\(\);', '          try { retriever.release(); } catch (IOException ignored) {}'
    Set-Content $java $content -NoNewline
    Write-Host "[OK] IOException patch applique."
} else {
    Write-Host "[SKIP] IOException deja patche."
}

Write-Host "`nPatches termines. Tu peux relancer : flutter build apk --release"
