param([int]$TargetPid, [string]$Keys)
# inject.ps1 — boshqa jarayon konsoliga klaviatura hodisalarini yozadi
# (WriteConsoleInput; fokus shart emas). Sinov-avtomatlashtirish uchun.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class CI {
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool FreeConsole();
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool AttachConsole(uint pid);
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct KEY_EVENT_RECORD {
    public bool bKeyDown; public ushort wRepeatCount; public ushort wVirtualKeyCode;
    public ushort wVirtualScanCode; public char UnicodeChar; public uint dwControlKeyState; }
  [StructLayout(LayoutKind.Explicit, CharSet=CharSet.Unicode)] public struct INPUT_RECORD {
    [FieldOffset(0)] public ushort EventType; [FieldOffset(4)] public KEY_EVENT_RECORD KeyEvent; }
  [DllImport("kernel32.dll", SetLastError=true)]
  public static extern bool WriteConsoleInput(IntPtr h, INPUT_RECORD[] recs, uint n, out uint written);
}
'@
[void][CI]::FreeConsole()
if (-not [CI]::AttachConsole([uint32]$TargetPid)) { Write-Output "ATTACH-FAIL"; exit 2 }
Write-Output "ATTACHED"
# Std handle emas — biriktirilgan konsolning KIRITISH bufferini ochamiz.
$h = [CI]::CreateFile("CONIN$", [uint32]3221225472, [uint32]3, [IntPtr]::Zero, [uint32]3, [uint32]0, [IntPtr]::Zero)
if ($h -eq [IntPtr]::Zero -or $h -eq [IntPtr](-1)) { Write-Output "CONIN-FAIL"; exit 3 }
function Send([uint16]$vk, [char]$ch, [uint16]$scan, [uint32]$ctrl) {
  $recs = New-Object 'CI+INPUT_RECORD[]' 2
  for ($i=0; $i -lt 2; $i++) {
    $recs[$i].EventType = 1
    $recs[$i].KeyEvent.bKeyDown = ($i -eq 0)
    $recs[$i].KeyEvent.wRepeatCount = 1
    $recs[$i].KeyEvent.wVirtualKeyCode = $vk
    $recs[$i].KeyEvent.wVirtualScanCode = $scan
    $recs[$i].KeyEvent.UnicodeChar = $ch
    $recs[$i].KeyEvent.dwControlKeyState = $ctrl
  }
  $out = [uint32]0
  $ok = [CI]::WriteConsoleInput($h, $recs, 2, [ref]$out)
  Write-Output ("WRITE ok=$ok n=$out")
}
foreach ($k in $Keys -split ',') {
  switch ($k) {
    'DOWN'  { Send 0x28 ([char]0)  0x50 256 }   # 256 = ENHANCED_KEY
    'UP'    { Send 0x26 ([char]0)  0x48 256 }
    'ENTER' { Send 0x0D ([char]13) 0x1C 0 }
    'ESC'   { Send 0x1B ([char]27) 0x01 0 }
    'Q'     { Send 0x51 ([char]'q') 0x10 0 }
  }
  Start-Sleep -Milliseconds 600
}
Write-Output "DONE"
exit 0
