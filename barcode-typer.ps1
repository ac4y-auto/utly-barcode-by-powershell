# ============================================================
#  BARCODE TYPER - Vonalkod szimulator WMS teszteleshez
# ============================================================
#  Hasznalat: jobb klikk -> "Run with PowerShell"
#  Vagy: powershell -ExecutionPolicy Bypass -File barcode-typer.ps1
#
#  Scroll Lock = GLOBALIS hotkey -> begepelio a kovetkezo vonalkodot
#  F8 = GLOBALIS hotkey -> torli a celmezo tartalmat
#  Klikk a listaban -> onnan folytatja a sort
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HotKeyHelper {
    [DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public const int WM_HOTKEY = 0x0312;
    public const uint VK_SCROLL = 0x91;
    public const uint VK_F8 = 0x77;
}
"@

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

# --- GUI felepitese ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Barcode Typer"
$form.Size = New-Object System.Drawing.Size(440, 560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.TopMost = $true
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# --- Vonalkod lista ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Vonalkod lista (soronkent egy kod):"
$lblTitle.Location = New-Object System.Drawing.Point(15, 12)
$lblTitle.Size = New-Object System.Drawing.Size(400, 22)
$form.Controls.Add($lblTitle)

$txtCodes = New-Object System.Windows.Forms.TextBox
$txtCodes.Multiline = $true
$txtCodes.ScrollBars = "Vertical"
$txtCodes.Location = New-Object System.Drawing.Point(15, 38)
$txtCodes.Size = New-Object System.Drawing.Size(395, 200)
$txtCodes.Font = New-Object System.Drawing.Font("Consolas", 11)
$txtCodes.Text = ($loadedCodes -join "`r`n")
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
$lblCode.ForeColor = [System.Drawing.Color]::FromArgb(0, 90, 180)
$lblCode.BackColor = [System.Drawing.Color]::FromArgb(235, 245, 255)
$lblCode.TextAlign = "MiddleCenter"
$lblCode.BorderStyle = "FixedSingle"
$form.Controls.Add($lblCode)

$lblIndex = New-Object System.Windows.Forms.Label
$lblIndex.Location = New-Object System.Drawing.Point(15, 314)
$lblIndex.Size = New-Object System.Drawing.Size(395, 20)
$lblIndex.ForeColor = [System.Drawing.Color]::Gray
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
$form.Controls.Add($txtDelay)

# --- Gombok ---
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "SCAN  (ScrollLock)"
$btnScan.Location = New-Object System.Drawing.Point(15, 415)
$btnScan.Size = New-Object System.Drawing.Size(185, 48)
$btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnScan.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 210)
$btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.FlatStyle = "Flat"
$form.Controls.Add($btnScan)

$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Text = "Reset"
$btnReset.Location = New-Object System.Drawing.Point(210, 415)
$btnReset.Size = New-Object System.Drawing.Size(95, 48)
$btnReset.FlatStyle = "Flat"
$form.Controls.Add($btnReset)

$btnLoad = New-Object System.Windows.Forms.Button
$btnLoad.Text = "Load .txt"
$btnLoad.Location = New-Object System.Drawing.Point(315, 415)
$btnLoad.Size = New-Object System.Drawing.Size(95, 48)
$btnLoad.FlatStyle = "Flat"
$form.Controls.Add($btnLoad)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "ScrollLock = scan | F8 = torles | Klikk = ugras"
$lblStatus.Location = New-Object System.Drawing.Point(15, 478)
$lblStatus.Size = New-Object System.Drawing.Size(395, 40)
$lblStatus.ForeColor = [System.Drawing.Color]::Gray
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
    Start-Sleep -Milliseconds ([int]$txtDelay.Text)
    $escaped = $code -replace '([+^%~(){}])', '{$1}'
    [System.Windows.Forms.SendKeys]::SendWait($escaped)
    if ($chkEnter.Checked) { [System.Windows.Forms.SendKeys]::SendWait("{ENTER}") }
    $script:idx++
    Update-UI
    $lblStatus.Text = "Elkuldte: $code"
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
[HotKeyHelper]::RegisterHotKey($form.Handle, 1, 0, [HotKeyHelper]::VK_SCROLL) | Out-Null
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

# GetAsyncKeyState pollolas a Scroll Lock-hoz
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeyState {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
}
"@

# Scroll Lock + F8 polling timer
$pollTimer = New-Object System.Windows.Forms.Timer
$pollTimer.Interval = 80
$script:scrollDown = $false
$script:f8Down = $false
$pollTimer.Add_Tick({
    # Scroll Lock -> Send-Next
    $state = [KeyState]::GetAsyncKeyState(0x91) # VK_SCROLL
    if (($state -band 0x8000) -ne 0) {
        if (-not $script:scrollDown) {
            $script:scrollDown = $true
            Send-Next
        }
    } else {
        $script:scrollDown = $false
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
