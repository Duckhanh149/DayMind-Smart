param(
  [Parameter(Mandatory=$true)][string]$OutputPath,
  [ValidateSet('foreground','tray','afterExit','doNotDisturb','afterReboot','upgrade')][string]$Scenario='foreground',
  [ValidateRange(30,1800)][int]$Seconds=120
)
$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class DayMindDeviceState {
 [DllImport("shell32.dll")] public static extern int SHQueryUserNotificationState(out int state);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr handle);
}
'@
try {
$samples=[System.Collections.Generic.List[object]]::new()
$clock=[Diagnostics.Stopwatch]::StartNew()
$previousCpu=$null; $previousTime=$null; $previousIdentity=''
$currentSession=(Get-Process -Id $PID).SessionId
while ($clock.Elapsed.TotalSeconds -lt $Seconds) {
  $processes=@(Get-Process -Name daymind_smart -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $currentSession })
  $cpu=0.0; $rss=0L; $private=0L; $visible=$false
  $identities=[System.Collections.Generic.List[string]]::new()
  foreach ($p in $processes) {
    try {
    $p.Refresh()
    $identity=[string]$p.Id+':'+[string]$p.StartTime.Ticks
    $cpu+=$p.TotalProcessorTime.TotalMilliseconds
    $rss+=$p.WorkingSet64; $private+=$p.PrivateMemorySize64
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) { $visible=$visible -or [DayMindDeviceState]::IsWindowVisible($p.MainWindowHandle) }
    $identities.Add($identity)
    } catch { <# Process may exit during sampling; never emit the raw error. #> }
    finally { $p.Dispose() }
  }
  $identitySet=($identities | Sort-Object) -join '|'
  $elapsed=$clock.Elapsed.TotalMilliseconds
  $percent=$null
  if ($identities.Count -gt 0 -and $identitySet -eq $previousIdentity -and $null -ne $previousCpu -and $cpu -ge $previousCpu -and $elapsed -gt $previousTime) { $percent=100*($cpu-$previousCpu)/($elapsed-$previousTime) }
  [int]$state=-1
  if ([DayMindDeviceState]::SHQueryUserNotificationState([ref]$state) -ne 0) { $state=-1 }
  $samples.Add(@{elapsedMs=[int64]$elapsed;processCount=$identities.Count;visible=$visible;workingSetBytes=$rss;privateBytes=$private;cpuPercentOneCore=$percent;osNotificationState=$state})
  $previousIdentity=$identitySet
  if ($identities.Count -gt 0) {$previousCpu=$cpu;$previousTime=$elapsed} else {$previousCpu=$null;$previousTime=$null}
  Start-Sleep -Seconds 1
}
$os=[Environment]::OSVersion.Version
$productType=0
try { $productType=[int](Get-CimInstance -ClassName Win32_OperatingSystem -Property ProductType).ProductType } catch { <# Unknown must not be inferred to be a client OS from build alone. #> }
$targetOS=if($productType -eq 1 -and $os.Build -ge 22000){'Windows11'}elseif($productType -eq 1 -and $os.Build -ge 17763){'Windows10'}elseif($productType -in 2,3){'WindowsServer'}else{'unknown_or_unsupported'}
$report=@{schema=1;scenario=$Scenario;osBuild=$os.Build;targetOS=$targetOS;samples=$samples;notificationVisibility='not_observed_by_tool';dataRetention='not_verified_by_tool';physicalAcceptanceComplete=$false}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output ('{"saved":true,"physicalAcceptanceComplete":false}')
} catch {
  Write-Output ('{"saved":false,"code":"capture_or_output_unavailable","physicalAcceptanceComplete":false}')
  exit 1
}
