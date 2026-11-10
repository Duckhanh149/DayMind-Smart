param([Parameter(Mandatory=$true)][ValidateSet('prepare','app','installer','cleanup')][string]$Mode)
$ErrorActionPreference = 'Stop'
$storeFile = Join-Path $env:RUNNER_TEMP 'daymind-production.pfx'
if ($Mode -eq 'cleanup') {
  if ($env:DAYMIND_WINDOWS_SIGNING_THUMBPRINT) {
    $item = "Cert:/CurrentUser/My/$env:DAYMIND_WINDOWS_SIGNING_THUMBPRINT"
    if (Test-Path $item) { Remove-Item $item -DeleteKey }
  }
  if (Test-Path $storeFile) { Remove-Item $storeFile -Force }
  exit 0
}
if ($Mode -eq 'prepare') {
  foreach ($name in @('DAYMIND_WINDOWS_PFX_BASE64','DAYMIND_WINDOWS_PFX_PASSWORD','DAYMIND_WINDOWS_CERT_SHA256')) {
    if (-not [Environment]::GetEnvironmentVariable($name)) { throw "Missing GitHub Actions secret/configuration: $name" }
  }
  $expected = $env:DAYMIND_WINDOWS_CERT_SHA256.Replace(':','').ToLowerInvariant()
  if ($expected -notmatch '^[a-f0-9]{64}$') { throw 'Invalid Windows public certificate fingerprint configuration' }
  $imported = @()
  try {
    $bytes = [Convert]::FromBase64String($env:DAYMIND_WINDOWS_PFX_BASE64)
    if ($bytes.Length -gt 1MB -or $bytes.Length -lt 100 -or (Test-Path $storeFile)) { throw 'Invalid PFX storage' }
    [IO.File]::WriteAllBytes($storeFile,$bytes)
    $secret = ConvertTo-SecureString $env:DAYMIND_WINDOWS_PFX_PASSWORD -AsPlainText -Force
    $imported = @(Import-PfxCertificate -FilePath $storeFile -CertStoreLocation 'Cert:/CurrentUser/My' -Password $secret)
    $candidates = @($imported | Where-Object { $_.HasPrivateKey })
    if ($candidates.Count -ne 1) { throw 'Expected one code-signing private identity' }
    $cert = $candidates[0]
    $actual = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($cert.RawData)).ToLowerInvariant()
    if (-not $cert.HasPrivateKey -or $actual -ne $expected) {
      if ($cert) { Remove-Item "Cert:/CurrentUser/My/$($cert.Thumbprint)" -DeleteKey }
      throw 'Fingerprint mismatch'
    }
    "DAYMIND_WINDOWS_SIGNING_THUMBPRINT=$($cert.Thumbprint)" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
    Write-Host 'Windows production certificate prepared; no private material is included in artifacts.'
  } catch {
    foreach ($item in $imported) {
      if ($item.HasPrivateKey -and (Test-Path "Cert:/CurrentUser/My/$($item.Thumbprint)")) {
        Remove-Item "Cert:/CurrentUser/My/$($item.Thumbprint)" -DeleteKey
      }
    }
    throw 'Windows certificate preparation failed; production artifact rejected.'
  }
  finally { if (Test-Path $storeFile) { Remove-Item $storeFile -Force } }
  exit 0
}
if ($env:DAYMIND_WINDOWS_SIGNING_THUMBPRINT -notmatch '^[0-9A-Fa-f]{40}$') { throw 'Missing prepared Windows signing identity' }
$signTool = Get-ChildItem "${env:ProgramFiles(x86)}/Windows Kits/10/bin/*/x64/signtool.exe" | Sort-Object FullName | Select-Object -Last 1
if (-not $signTool) { throw 'Windows SDK signing tool is unavailable' }
$file = if ($Mode -eq 'app') { 'build/windows/x64/runner/Release/daymind_smart.exe' } else { 'build/windows-installer/DayMind-Setup.exe' }
$output = & $signTool.FullName sign /sha1 $env:DAYMIND_WINDOWS_SIGNING_THUMBPRINT /fd SHA256 /tr https://timestamp.digicert.com /td SHA256 $file 2>&1
if ($LASTEXITCODE -ne 0) { throw 'Windows code signing failed; production artifact rejected.' }
$signature = Get-AuthenticodeSignature $file
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $env:DAYMIND_WINDOWS_SIGNING_THUMBPRINT -or -not $signature.TimeStamperCertificate) {
  throw 'Windows signature/chain/timestamp verification failed; production artifact rejected.'
}
Write-Host "Verified trusted timestamped signature on $(Split-Path $file -Leaf)."
