param(
    [string]$VidPid = "2357:0138",
    [string]$Distro = "kali-linux"
)

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

if (-not (Get-Command usbipd -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Installing usbipd-win..."
    winget install --id dorssel.usbipd-win --accept-source-agreements --accept-package-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

$deviceLine = usbipd list | Where-Object { $_ -match [regex]::Escape($VidPid) }
if (-not $deviceLine) {
    Write-Host "[-] Device $VidPid not found. Plug in the adapter and retry."
    exit 1
}

if ($deviceLine -match '(\d+-\d+)') {
    $busid = $matches[1]
} else {
    Write-Host "[-] Could not parse bus ID from: $deviceLine"
    exit 1
}

Write-Host "[*] Found adapter at bus ID: $busid"

if ($deviceLine -match 'Not shared') {
    Write-Host "[*] Binding adapter (requires admin)..."
    Start-Process usbipd -ArgumentList "bind --busid $busid" -Verb RunAs -Wait -WindowStyle Hidden
}

Write-Host "[*] Starting WSL..."
wsl -d $Distro -u root -- echo "WSL ready" | Out-Null

Write-Host "[*] Attaching USB adapter to WSL..."
usbipd attach --wsl --busid $busid

Start-Sleep -Seconds 2

$state = (usbipd list | Where-Object { $_ -match [regex]::Escape($VidPid) })
if ($state -match 'Attached') {
    Write-Host "[+] Adapter attached. Run inside WSL:"
    Write-Host "    bash monitor.sh"
} else {
    Write-Host "[-] Attach may have failed. Check: usbipd list"
}
