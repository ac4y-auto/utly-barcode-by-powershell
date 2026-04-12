# ============================================================
#  BARCODE TYPER - Vonalkod szimulator WMS teszteleshez
# ============================================================
#  Hasznalat: jobb klikk -> "Run with PowerShell"
#  Vagy: powershell -ExecutionPolicy Bypass -File barcode-typer.ps1
#
#  F9 = GLOBALIS hotkey -> begepelio a kovetkezo vonalkodot
#  F8 = GLOBALIS hotkey -> torli a celmezo tartalmat
#  Klikk a listaban -> onnan folytatja a sort
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DarkTitle {
    [DllImport("dwmapi.dll", PreserveSig = true)]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    public static void Enable(IntPtr hwnd) {
        int val = 1;
        DwmSetWindowAttribute(hwnd, 20, ref val, 4);
    }
}
public class HotKeyHelper {
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public const int WM_HOTKEY = 0x0312;
    public const uint VK_F9 = 0x78;
    public const uint VK_F8 = 0x77;
}
public class WinApi {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hWnd, EnumChildProc cb, IntPtr lp);
    public delegate bool EnumChildProc(IntPtr h, IntPtr lp);
    [DllImport("user32.dll")] public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT {
        public uint type;
        public INPUTUNION u;
    }
    [StructLayout(LayoutKind.Explicit)]
    public struct INPUTUNION {
        [FieldOffset(0)] public KEYBDINPUT ki;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }
    public const uint INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const uint KEYEVENTF_UNICODE = 0x0004;

    // Find Chrome_RenderWidgetHostHWND child window
    public static IntPtr FindRenderWidget(IntPtr parentHwnd) {
        IntPtr found = IntPtr.Zero;
        EnumChildWindows(parentHwnd, (h, lp) => {
            var sb = new System.Text.StringBuilder(128);
            GetClassName(h, sb, 128);
            if (sb.ToString() == "Chrome_RenderWidgetHostHWND") { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    // Inject string as Unicode keystrokes via SendInput (OS-level, bypasses focus issues)
    public static void SendString(string text) {
        var inputs = new System.Collections.Generic.List<INPUT>();
        foreach (char c in text) {
            var down = new INPUT { type = INPUT_KEYBOARD };
            down.u.ki = new KEYBDINPUT { wScan = (ushort)c, dwFlags = KEYEVENTF_UNICODE };
            var up = new INPUT { type = INPUT_KEYBOARD };
            up.u.ki = new KEYBDINPUT { wScan = (ushort)c, dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP };
            inputs.Add(down);
            inputs.Add(up);
        }
        SendInput((uint)inputs.Count, inputs.ToArray(), System.Runtime.InteropServices.Marshal.SizeOf(typeof(INPUT)));
    }

    // Focus Chrome renderer via AttachThreadInput (bypasses SetForegroundWindow restrictions)
    public static bool FocusWindow(IntPtr targetHwnd) {
        IntPtr renderHwnd = FindRenderWidget(targetHwnd);
        if (renderHwnd == IntPtr.Zero) renderHwnd = targetHwnd;
        uint pid = 0;
        uint targetThread = GetWindowThreadProcessId(targetHwnd, out pid);
        uint currentThread = GetCurrentThreadId();
        AttachThreadInput(currentThread, targetThread, true);
        SetFocus(renderHwnd);
        SetForegroundWindow(targetHwnd);
        AttachThreadInput(currentThread, targetThread, false);
        return true;
    }
}
"@

# Az utolso celablak trackelese
$script:targetHwnd = [IntPtr]::Zero

# --- Vonalkod fajl kezeles ---
$script:codesFile = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "codes.txt"
$defaultCodes = @("1B1", "2POLC", "5901780569037", "5900458000933", "fakebin", "CLEAR")

if (Test-Path $script:codesFile) {
    $loadedCodes = Get-Content $script:codesFile -Encoding UTF8
} else {
    $loadedCodes = $defaultCodes
    $defaultCodes | Set-Content $script:codesFile -Encoding UTF8
}

function Save-CodesToFile {
    $codes = $txtCodes.Text.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    $codes | Set-Content $script:codesFile -Encoding UTF8
}

# --- Dark theme szinek ---
$bgColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$fgColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$inputBg = [System.Drawing.Color]::FromArgb(45, 45, 45)
$inputFg = [System.Drawing.Color]::FromArgb(230, 230, 230)
$accentBg = [System.Drawing.Color]::FromArgb(0, 120, 210)
$codeBg = [System.Drawing.Color]::FromArgb(20, 40, 60)
$codeFg = [System.Drawing.Color]::FromArgb(80, 180, 255)
$btnBg = [System.Drawing.Color]::FromArgb(55, 55, 55)
$btnFg = [System.Drawing.Color]::FromArgb(200, 200, 200)

# --- GUI felepitese ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Barcode Typer"
$form.Size = New-Object System.Drawing.Size(440, 595)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.TopMost = $true
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.BackColor = $bgColor
$form.ForeColor = $fgColor
[DarkTitle]::Enable($form.Handle)

# --- Vonalkod lista ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Vonalkod lista (soronkent egy kod):"
$lblTitle.Location = New-Object System.Drawing.Point(15, 12)
$lblTitle.Size = New-Object System.Drawing.Size(400, 22)
$lblTitle.ForeColor = $fgColor
$form.Controls.Add($lblTitle)

$txtCodes = New-Object System.Windows.Forms.TextBox
$txtCodes.Multiline = $true
$txtCodes.ScrollBars = "Vertical"
$txtCodes.Location = New-Object System.Drawing.Point(15, 38)
$txtCodes.Size = New-Object System.Drawing.Size(395, 200)
$txtCodes.Font = New-Object System.Drawing.Font("Consolas", 11)
$txtCodes.Text = ($loadedCodes -join "`r`n")
$txtCodes.BackColor = $inputBg
$txtCodes.ForeColor = $inputFg
$form.Controls.Add($txtCodes)

# --- Kovetkezo kod kijelzo ---
$lblNext = New-Object System.Windows.Forms.Label
$lblNext.Text = "Kovetkezo kod:"
$lblNext.Location = New-Object System.Drawing.Point(15, 248)
$lblNext.Size = New-Object System.Drawing.Size(400, 20)
$form.Controls.Add($lblNext)

$lblCode = New-Object System.Windows.Forms.Label
$lblCode.Location = New-Object System.Drawing.Point(15, 270)
$lblCode.Size = New-Object System.Drawing.Size(395, 40)
$lblCode.Font = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Bold)
$lblCode.ForeColor = $codeFg
$lblCode.BackColor = $codeBg
$lblCode.TextAlign = "MiddleCenter"
$lblCode.BorderStyle = "FixedSingle"
$form.Controls.Add($lblCode)

$lblIndex = New-Object System.Windows.Forms.Label
$lblIndex.Location = New-Object System.Drawing.Point(15, 314)
$lblIndex.Size = New-Object System.Drawing.Size(395, 20)
$lblIndex.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
$lblIndex.TextAlign = "MiddleCenter"
$form.Controls.Add($lblIndex)

# --- Opciok ---
$chkEnter = New-Object System.Windows.Forms.CheckBox
$chkEnter.Text = "Enter kuldese a kod utan"
$chkEnter.Location = New-Object System.Drawing.Point(15, 344)
$chkEnter.Size = New-Object System.Drawing.Size(190, 24)
$chkEnter.Checked = $true
$form.Controls.Add($chkEnter)

$chkLoop = New-Object System.Windows.Forms.CheckBox
$chkLoop.Text = "Lista ismetlese (loop)"
$chkLoop.Location = New-Object System.Drawing.Point(215, 344)
$chkLoop.Size = New-Object System.Drawing.Size(190, 24)
$chkLoop.Checked = $true
$form.Controls.Add($chkLoop)

$lblDelay = New-Object System.Windows.Forms.Label
$lblDelay.Text = "Delay (ms):"
$lblDelay.Location = New-Object System.Drawing.Point(15, 376)
$lblDelay.Size = New-Object System.Drawing.Size(80, 24)
$form.Controls.Add($lblDelay)

$txtDelay = New-Object System.Windows.Forms.TextBox
$txtDelay.Text = "50"
$txtDelay.Location = New-Object System.Drawing.Point(100, 374)
$txtDelay.Size = New-Object System.Drawing.Size(50, 24)
$txtDelay.BackColor = $inputBg
$txtDelay.ForeColor = $inputFg
$form.Controls.Add($txtDelay)

# --- Prefix / Suffix ---
$lblPrefix = New-Object System.Windows.Forms.Label
$lblPrefix.Text = "Prefix:"
$lblPrefix.Location = New-Object System.Drawing.Point(15, 410)
$lblPrefix.Size = New-Object System.Drawing.Size(50, 24)
$form.Controls.Add($lblPrefix)

$txtPrefix = New-Object System.Windows.Forms.TextBox
$txtPrefix.Text = "`$"
$txtPrefix.Location = New-Object System.Drawing.Point(65, 408)
$txtPrefix.Size = New-Object System.Drawing.Size(60, 24)
$txtPrefix.BackColor = $inputBg
$txtPrefix.ForeColor = [System.Drawing.Color]::FromArgb(80, 200, 120)
$txtPrefix.Font = New-Object System.Drawing.Font("Consolas", 11)
$form.Controls.Add($txtPrefix)

$lblSuffix = New-Object System.Windows.Forms.Label
$lblSuffix.Text = "Suffix:"
$lblSuffix.Location = New-Object System.Drawing.Point(145, 410)
$lblSuffix.Size = New-Object System.Drawing.Size(50, 24)
$form.Controls.Add($lblSuffix)

$txtSuffix = New-Object System.Windows.Forms.TextBox
$txtSuffix.Text = "#"
$txtSuffix.Location = New-Object System.Drawing.Point(195, 408)
$txtSuffix.Size = New-Object System.Drawing.Size(60, 24)
$txtSuffix.BackColor = $inputBg
$txtSuffix.ForeColor = [System.Drawing.Color]::FromArgb(80, 200, 120)
$txtSuffix.Font = New-Object System.Drawing.Font("Consolas", 11)
$form.Controls.Add($txtSuffix)

$btnTarget = New-Object System.Windows.Forms.Button
$btnTarget.Text = "Celablak rogzitese (3mp mulva)"
$btnTarget.Location = New-Object System.Drawing.Point(270, 404)
$btnTarget.Size = New-Object System.Drawing.Size(155, 32)
$btnTarget.FlatStyle = "Flat"
$btnTarget.BackColor = [System.Drawing.Color]::FromArgb(60, 80, 40)
$btnTarget.ForeColor = [System.Drawing.Color]::FromArgb(120, 220, 80)
$btnTarget.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($btnTarget)

$script:countdown = 3
$countTimer = New-Object System.Windows.Forms.Timer
$countTimer.Interval = 1000
$countTimer.Add_Tick({
    $script:countdown--
    if ($script:countdown -gt 0) {
        $btnTarget.Text = "Kattints a celablakra! ($script:countdown)"
    } else {
        $countTimer.Stop()
        $script:targetHwnd = [WinApi]::GetForegroundWindow()
        $btnTarget.Text = "Celablak: $($script:targetHwnd)"
        $btnTarget.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 30)
        $lblStatus.Text = "Celablak rogzitve! F9 = scan ide."
        $script:countdown = 3
    }
})
$btnTarget.Add_Click({
    $btnTarget.Text = "Kattints a celablakra! (3)"
    $btnTarget.BackColor = [System.Drawing.Color]::FromArgb(80, 60, 20)
    $script:countdown = 3
    $countTimer.Start()
})

# --- Gombok ---
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "SCAN  (F9)"
$btnScan.Location = New-Object System.Drawing.Point(15, 445)
$btnScan.Size = New-Object System.Drawing.Size(185, 48)
$btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnScan.BackColor = $accentBg
$btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.FlatStyle = "Flat"
$form.Controls.Add($btnScan)

$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Text = "Reset"
$btnReset.Location = New-Object System.Drawing.Point(210, 445)
$btnReset.Size = New-Object System.Drawing.Size(95, 48)
$btnReset.FlatStyle = "Flat"
$btnReset.BackColor = $btnBg
$btnReset.ForeColor = $btnFg
$form.Controls.Add($btnReset)

$btnLoad = New-Object System.Windows.Forms.Button
$btnLoad.Text = "Load .txt"
$btnLoad.Location = New-Object System.Drawing.Point(315, 445)
$btnLoad.Size = New-Object System.Drawing.Size(95, 48)
$btnLoad.FlatStyle = "Flat"
$btnLoad.BackColor = $btnBg
$btnLoad.ForeColor = $btnFg
$form.Controls.Add($btnLoad)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "F9 = scan | F8 = torles | Klikk = ugras"
$lblStatus.Location = New-Object System.Drawing.Point(15, 505)
$lblStatus.Size = New-Object System.Drawing.Size(395, 40)
$lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 140)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Controls.Add($lblStatus)

# --- Logika ---
$script:idx = 0

function Get-Codes {
    $txtCodes.Text.Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

function Update-UI {
    $codes = Get-Codes
    if ($codes.Count -eq 0) { $lblCode.Text = "(ures lista)"; $lblIndex.Text = ""; return }
    if ($script:idx -ge $codes.Count) {
        if ($chkLoop.Checked) { $script:idx = 0 } else { $lblCode.Text = "(lista vege)"; $lblIndex.Text = "$($codes.Count) / $($codes.Count)"; return }
    }
    $lblCode.Text = $codes[$script:idx]
    $lblIndex.Text = "$($script:idx + 1) / $($codes.Count)"
}

function Send-Next {
    $codes = Get-Codes
    if ($codes.Count -eq 0) { return }
    if ($script:idx -ge $codes.Count) {
        if ($chkLoop.Checked) { $script:idx = 0 } else { return }
    }
    $code = $codes[$script:idx]

    $prefix = $txtPrefix.Text
    $suffix = $txtSuffix.Text
    $full   = $prefix + $code + $suffix
    if ($chkEnter.Checked) { $full += "`r" }

    if ($script:targetHwnd -eq [IntPtr]::Zero) {
        $lblStatus.Text = "HIBA: Nincs celablak! Kattints a 'Celablak rogzitese' gombra!"
        return
    }

    # 1. AttachThreadInput + SetFocus -> Chrome rendererre fokuszal (fokusz-lopas bypass)
    [WinApi]::FocusWindow($script:targetHwnd) | Out-Null
    Start-Sleep -Milliseconds ([int]$txtDelay.Text)

    # 2. SendInput Unicode injektalas (OS-szintu, a Chrome JS keydown-t lát)
    [WinApi]::SendString($full)

    $script:idx++
    Update-UI
    $lblStatus.Text = "OK: $full -> [$($script:targetHwnd)]"
}

$btnScan.Add_Click({ Send-Next })
$btnReset.Add_Click({ $script:idx = 0; Update-UI; $lblStatus.Text = "Reset." })
$btnLoad.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Text (*.txt)|*.txt|CSV (*.csv)|*.csv|All (*.*)|*.*"
    if ($dlg.ShowDialog() -eq "OK") { $txtCodes.Text = (Get-Content $dlg.FileName -Raw); $script:idx = 0; Update-UI }
})
$txtCodes.Add_TextChanged({ $script:idx = 0; Update-UI; Save-CodesToFile })
$txtCodes.Add_MouseClick({
    $charIdx = $txtCodes.GetCharIndexFromPosition($_.Location)
    $lineIdx = $txtCodes.GetLineFromCharIndex($charIdx)
    $codes = Get-Codes
    if ($lineIdx -lt $codes.Count) {
        $script:idx = $lineIdx
        Update-UI
        $lblStatus.Text = "Kivalasztva: $($codes[$lineIdx])"
    }
})

# --- Globalis hotkey regisztracio ---
[HotKeyHelper]::RegisterHotKey($form.Handle, 1, 0, [HotKeyHelper]::VK_F9) | Out-Null
[HotKeyHelper]::RegisterHotKey($form.Handle, 2, 0, [HotKeyHelper]::VK_F8) | Out-Null

$form.Add_FormClosing({
    [HotKeyHelper]::UnregisterHotKey($form.Handle, 1) | Out-Null
    [HotKeyHelper]::UnregisterHotKey($form.Handle, 2) | Out-Null
})

function Clear-TargetField {
    [System.Windows.Forms.SendKeys]::SendWait("^a")
    Start-Sleep -Milliseconds 20
    [System.Windows.Forms.SendKeys]::SendWait("{DELETE}")
    $lblStatus.Text = "Mezo torolve (F8)"
}

# GetAsyncKeyState pollolas az F9-hez
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeyState {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
}
"@

# F9 + F8 polling timer
$pollTimer = New-Object System.Windows.Forms.Timer
$pollTimer.Interval = 80
$script:f9Down = $false
$script:f8Down = $false
$pollTimer.Add_Tick({
    # F9 -> Send-Next
    $state = [KeyState]::GetAsyncKeyState(0x78) # VK_F9
    if (($state -band 0x8000) -ne 0) {
        if (-not $script:f9Down) {
            $script:f9Down = $true
            Send-Next
        }
    } else {
        $script:f9Down = $false
    }
    # F8 -> Clear-TargetField
    $f8state = [KeyState]::GetAsyncKeyState(0x77) # VK_F8
    if (($f8state -band 0x8000) -ne 0) {
        if (-not $script:f8Down) {
            $script:f8Down = $true
            Clear-TargetField
        }
    } else {
        $script:f8Down = $false
    }
})
$pollTimer.Start()
$form.Add_FormClosing({ $pollTimer.Stop() })

# --- Start ---
Update-UI
[void]$form.ShowDialog()
