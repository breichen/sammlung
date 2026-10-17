# Im Projektordner ausführen (nach `flutter create .` und `flutter pub get`).
# Setzt den App-Namen "Sammlung" und erzeugt die Icons aus assets/icon/.
# Aufruf: powershell -ExecutionPolicy Bypass -File .\tool\apply_branding.ps1
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)   # UTF-8 ohne BOM

function Update-File([string]$path, [scriptblock]$change) {
    if (Test-Path $path) {
        $full = (Resolve-Path $path).Path
        $text = [System.IO.File]::ReadAllText($full, $utf8)
        $new = & $change $text
        [System.IO.File]::WriteAllText($full, $new, $utf8)
    }
}

Update-File 'android/app/src/main/AndroidManifest.xml' {
    param($t)
    [regex]::Replace($t, 'android:label="[^"]*"', 'android:label="Sammlung"')
}

Update-File 'ios/Runner/Info.plist' {
    param($t)
    $t = [regex]::Replace($t, '(<key>CFBundleDisplayName</key>\s*<string>)[^<]*', '${1}Sammlung')
    $t = [regex]::Replace($t, '(<key>CFBundleName</key>\s*<string>)[^<]*', '${1}Sammlung')
    $t
}

dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
