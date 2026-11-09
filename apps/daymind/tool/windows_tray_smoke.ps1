$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DayMindWindowTest {
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
}
'@
$directory = (Resolve-Path 'build/windows/x64/runner/Release').Path
$process = Start-Process (Join-Path $directory 'daymind_smart.exe') -WorkingDirectory $directory -PassThru
try {
  $deadline = (Get-Date).AddSeconds(45)
  $handle = [IntPtr]::Zero
  while ((Get-Date) -lt $deadline -and $handle -eq [IntPtr]::Zero) {
    Start-Sleep -Milliseconds 200
    $process.Refresh()
    if ($process.HasExited) { throw 'Application exited during startup' }
    $handle = $process.MainWindowHandle
  }
  if ($handle -eq [IntPtr]::Zero) { throw 'Window did not appear' }
  [DayMindWindowTest]::PostMessage($handle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
  Start-Sleep -Milliseconds 600
  $process.Refresh()
  if ($process.HasExited -or [DayMindWindowTest]::IsWindowVisible($handle)) { throw 'WM_CLOSE did not keep app alive in tray' }
  [DayMindWindowTest]::PostMessage($handle, 0x0111, [IntPtr]801, [IntPtr]::Zero) | Out-Null
  Start-Sleep -Milliseconds 600
  if (-not [DayMindWindowTest]::IsWindowVisible($handle)) { throw 'Open command did not restore window' }
  [DayMindWindowTest]::PostMessage($handle, 0x0111, [IntPtr]802, [IntPtr]::Zero) | Out-Null
  if (-not $process.WaitForExit(15000)) { throw 'Quit command did not exit the process' }
  $startup = Get-ItemProperty 'HKCU:/Software/Microsoft/Windows/CurrentVersion/Run' -ErrorAction SilentlyContinue
  if ($startup -and ($startup.PSObject.Properties.Name | Where-Object { $_ -match 'daymind' })) { throw 'Unexpected DayMind startup registration' }
  Write-Host 'PASS: real Windows process survives close, restores, quits, and has no startup registration.'
} finally {
  if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
}
