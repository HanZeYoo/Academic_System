$files = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    $newContent = $content -replace ",\s*'4th Term'", ""
    $newContent = $newContent -replace ",\s*DropdownMenuItem\(value:\s*'4th Term',\s*child:\s*Text\('4th Term'\)\)", ""
    $newContent = $newContent -replace "'4th Term'", ""
    if ($content -ne $newContent) {
        Set-Content -Path $f.FullName -Value $newContent -Encoding UTF8
        Write-Output "Updated: $($f.FullName)"
    }
}
