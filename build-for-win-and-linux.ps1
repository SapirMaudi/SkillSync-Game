cd server

$env:GOOS="windows"
$env:GOARCH="amd64"
go build -o ctf-server-windows.exe ./cmd

$env:GOOS="linux"
$env:GOARCH="amd64"
go build -o ctf-server-linux ./cmd

Remove-Item Env:GOOS
Remove-Item Env:GOARCH

Write-Host "Build complete."