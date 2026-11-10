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
  $second = Start-Process (Join-Path $directory 'daymind_smart.exe') -WorkingDirectory $directory -PassThru
  try {
    if (-not $second.WaitForExit(12000) -or $second.ExitCode -ne 0) { throw 'Second launch did not hand over to the existing process' }
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline -and -not [DayMindWindowTest]::IsWindowVisible($handle)) { Start-Sleep -Milliseconds 100 }
    if (-not [DayMindWindowTest]::IsWindowVisible($handle)) { throw 'Second launch did not restore the original tray window' }
    $process.Refresh()
    if ($process.HasExited) { throw 'Second launch replaced the original process' }
    Write-Host 'PASS: second launch opens the original tray window and exits without another engine/workspace.'
  } finally { if (-not $second.HasExited) { Stop-Process -Id $second.Id -Force } }
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
