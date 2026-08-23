$files = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    $newContent = $content -replace '1st Quarter', '1st Term'
    $newContent = $newContent -replace '2nd Quarter', '2nd Term'
    $newContent = $newContent -replace '3rd Quarter', '3rd Term'
    $newContent = $newContent -replace '4th Quarter', '4th Term'
    if ($content -ne $newContent) {
        Set-Content -Path $f.FullName -Value $newContent -Encoding UTF8
        Write-Output "Updated: $($f.FullName)"
    }
}
