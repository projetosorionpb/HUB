#Requires -Version 5.0
# =============================================================================
# INSTALADOR DE SCRIPTS LISP - NanoCAD 5
# Versao: 1.0
# Descricao: Instala/Atualiza os scripts LISP automaticamente no NanoCAD 5
# =============================================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# =============================================================================
# CONFIGURACOES
# =============================================================================
$INSTALL_DIR    = Join-Path $env:LOCALAPPDATA "NanoCAD_Scripts_CAD"
$REG_BASE       = "HKCU:\SOFTWARE\Nanosoft AS\nanoCAD Int\5.0\Profile\Appload\Startup"
$ENABLED_VALUE  = [byte[]](5,0,0,0,1,0,0,0)

# Determina a pasta de origem e carrega todos os scripts .lsp dinamicamente
$GLOBAL_SRC_DIR = Split-Path -Parent $MyInvocation.ScriptName
if (-not $GLOBAL_SRC_DIR -or -not (Test-Path $GLOBAL_SRC_DIR)) { $GLOBAL_SRC_DIR = $PSScriptRoot }
if (-not $GLOBAL_SRC_DIR) { $GLOBAL_SRC_DIR = (Get-Location).Path }

$SCRIPTS = @(Get-ChildItem -Path $GLOBAL_SRC_DIR -Filter "*.lsp" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)

# Arquivo de versao local
$VERSION_FILE = Join-Path $INSTALL_DIR "version.txt"

# =============================================================================
# FUNCOES AUXILIARES
# =============================================================================

function Get-InstalledVersion {
    if (Test-Path $VERSION_FILE) {
        return (Get-Content $VERSION_FILE -Raw).Trim()
    }
    return $null
}

function Write-InstalledVersion($ver) {
    $ver | Set-Content $VERSION_FILE -Encoding UTF8
}

function Get-NextAppKey {
    $i = 0
    while (Test-Path "$REG_BASE\app$i") { $i++ }
    return "app$i"
}

function Remove-OldEntries($scriptName) {
    if (-not (Test-Path $REG_BASE)) { return }
    $toRemove = @()
    Get-ChildItem $REG_BASE | ForEach-Object {
        $item  = $_
        $props = Get-ItemProperty $item.PSPath -ErrorAction SilentlyContinue
        if ($props -and $props.Loader) {
            $loader = [System.IO.Path]::GetFileName($props.Loader)
            if ($loader -ieq $scriptName) {
                $toRemove += $item.PSPath
            }
        }
    }
    foreach ($p in $toRemove) {
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }
}

function Register-Script($scriptPath) {
    $scriptName = [System.IO.Path]::GetFileName($scriptPath)
    Remove-OldEntries $scriptName

    $key     = Get-NextAppKey
    $newPath = "$REG_BASE\$key"
    New-Item -Path $newPath -Force | Out-Null
    Set-ItemProperty -Path $newPath -Name "Loader" -Value $scriptPath
    Set-ItemProperty -Path $newPath -Name "Type"   -Value "LISP"

    $regKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
        "SOFTWARE\Nanosoft AS\nanoCAD Int\5.0\Profile\Appload\Startup\$key", $true
    )
    if ($regKey) {
        $regKey.SetValue("Enabled", $ENABLED_VALUE, [Microsoft.Win32.RegistryValueKind]::Binary)
        $regKey.Close()
    }
}
function Reindex-StartupApps {
    $apps = @()
    if (Test-Path $REG_BASE) {
        Get-ChildItem $REG_BASE | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($props -and $props.Loader) {
                $apps += @{
                    Loader = $props.Loader
                    Type = $props.Type
                    Enabled = $props.Enabled
                }
            }
        }
        Remove-Item $REG_BASE -Recurse -Force
    }
    New-Item -Path $REG_BASE -Force | Out-Null
    
    for ($i = 0; $i -lt $apps.Count; $i++) {
        $app = $apps[$i]
        $newPath = "$REG_BASE\app$i"
        New-Item -Path $newPath -Force | Out-Null
        Set-ItemProperty -Path $newPath -Name "Loader" -Value $app.Loader
        Set-ItemProperty -Path $newPath -Name "Type"   -Value $app.Type
        
        $regKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("SOFTWARE\Nanosoft AS\nanoCAD Int\5.0\Profile\Appload\Startup\app$i", $true)
        if ($regKey -and $app.Enabled) {
            $regKey.SetValue("Enabled", $app.Enabled, [Microsoft.Win32.RegistryValueKind]::Binary)
            $regKey.Close()
        }
    }
}

# =============================================================================
# INTERFACE GRAFICA
# =============================================================================

$form = New-Object System.Windows.Forms.Form
$form.Text            = "Instalador de Scripts LISP - NanoCAD 5"
$form.ClientSize      = New-Object System.Drawing.Size(630, 600)
$form.StartPosition   = "CenterScreen"
$form.BackColor       = [System.Drawing.Color]::FromArgb(18, 18, 30)
$form.ForeColor       = [System.Drawing.Color]::White
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 9)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false

# --- TITULO ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "Scripts LISP para NanoCAD 5"
$lblTitle.Font      = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
$lblTitle.Location  = New-Object System.Drawing.Point(20, 18)
$lblTitle.Size      = New-Object System.Drawing.Size(590, 32)
$form.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text      = "Instala e registra automaticamente os scripts na Startup Suite do NanoCAD"
$lblSub.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblSub.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 175)
$lblSub.Location  = New-Object System.Drawing.Point(20, 54)
$lblSub.Size      = New-Object System.Drawing.Size(590, 20)
$form.Controls.Add($lblSub)

# Linha separadora
$sep1           = New-Object System.Windows.Forms.Panel
$sep1.Location  = New-Object System.Drawing.Point(20, 82)
$sep1.Size      = New-Object System.Drawing.Size(590, 1)
$sep1.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 80)
$form.Controls.Add($sep1)

# --- PASTA DESTINO ---
$lblDest = New-Object System.Windows.Forms.Label
$lblDest.Text      = "Pasta de instalacao:"
$lblDest.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblDest.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 220)
$lblDest.Location  = New-Object System.Drawing.Point(20, 97)
$lblDest.Size      = New-Object System.Drawing.Size(590, 18)
$form.Controls.Add($lblDest)

$txtDest = New-Object System.Windows.Forms.TextBox
$txtDest.Text        = $INSTALL_DIR
$txtDest.ReadOnly    = $true
$txtDest.Location    = New-Object System.Drawing.Point(20, 118)
$txtDest.Size        = New-Object System.Drawing.Size(590, 24)
$txtDest.BackColor   = [System.Drawing.Color]::FromArgb(28, 28, 44)
$txtDest.ForeColor   = [System.Drawing.Color]::FromArgb(80, 220, 140)
$txtDest.BorderStyle = "FixedSingle"
$form.Controls.Add($txtDest)

# --- VERSAO INSTALADA ---
$installedVer = Get-InstalledVersion
$lblVer = New-Object System.Windows.Forms.Label
if ($installedVer) {
    $lblVer.Text      = "Versao instalada: $installedVer"
    $lblVer.ForeColor = [System.Drawing.Color]::FromArgb(80, 210, 130)
} else {
    $lblVer.Text      = "Nenhuma versao instalada anteriormente"
    $lblVer.ForeColor = [System.Drawing.Color]::FromArgb(210, 120, 60)
}
$lblVer.Font      = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Italic)
$lblVer.Location  = New-Object System.Drawing.Point(20, 148)
$lblVer.Size      = New-Object System.Drawing.Size(590, 18)
$form.Controls.Add($lblVer)

# Linha separadora 2
$sep2           = New-Object System.Windows.Forms.Panel
$sep2.Location  = New-Object System.Drawing.Point(20, 172)
$sep2.Size      = New-Object System.Drawing.Size(590, 1)
$sep2.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 80)
$form.Controls.Add($sep2)

# --- LISTA DE SCRIPTS ---
$lblScripts = New-Object System.Windows.Forms.Label
$lblScripts.Text      = "Scripts a instalar/atualizar (marque os desejados):"
$lblScripts.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblScripts.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 220)
$lblScripts.Location  = New-Object System.Drawing.Point(20, 182)
$lblScripts.Size      = New-Object System.Drawing.Size(590, 20)
$form.Controls.Add($lblScripts)

$chkList = New-Object System.Windows.Forms.CheckedListBox
$chkList.Location     = New-Object System.Drawing.Point(20, 206)
$chkList.Size         = New-Object System.Drawing.Size(590, 170)
$chkList.BackColor    = [System.Drawing.Color]::FromArgb(24, 24, 40)
$chkList.ForeColor    = [System.Drawing.Color]::FromArgb(210, 210, 235)
$chkList.BorderStyle  = "FixedSingle"
$chkList.CheckOnClick = $true
$chkList.Font         = New-Object System.Drawing.Font("Consolas", 9)
foreach ($s in $SCRIPTS) {
    $idx = $chkList.Items.Add($s)
    $chkList.SetItemChecked($idx, $true)
}
$form.Controls.Add($chkList)

# Botoes Marcar/Desmarcar todos
$btnAll = New-Object System.Windows.Forms.Button
$btnAll.Text      = "Marcar Todos"
$btnAll.Location  = New-Object System.Drawing.Point(20, 385)
$btnAll.Size      = New-Object System.Drawing.Size(115, 26)
$btnAll.FlatStyle = "Flat"
$btnAll.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(55, 75, 115)
$btnAll.BackColor = [System.Drawing.Color]::FromArgb(36, 55, 88)
$btnAll.ForeColor = [System.Drawing.Color]::White
$btnAll.Add_Click({ for ($i = 0; $i -lt $chkList.Items.Count; $i++) { $chkList.SetItemChecked($i, $true) } })
$form.Controls.Add($btnAll)

$btnNone = New-Object System.Windows.Forms.Button
$btnNone.Text      = "Desmarcar Todos"
$btnNone.Location  = New-Object System.Drawing.Point(143, 385)
$btnNone.Size      = New-Object System.Drawing.Size(125, 26)
$btnNone.FlatStyle = "Flat"
$btnNone.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(55, 75, 115)
$btnNone.BackColor = [System.Drawing.Color]::FromArgb(36, 55, 88)
$btnNone.ForeColor = [System.Drawing.Color]::White
$btnNone.Add_Click({ for ($i = 0; $i -lt $chkList.Items.Count; $i++) { $chkList.SetItemChecked($i, $false) } })
$form.Controls.Add($btnNone)

# Linha separadora 3
$sep3           = New-Object System.Windows.Forms.Panel
$sep3.Location  = New-Object System.Drawing.Point(20, 420)
$sep3.Size      = New-Object System.Drawing.Size(590, 1)
$sep3.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 80)
$form.Controls.Add($sep3)

# --- LOG ---
$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text      = "Log de instalacao:"
$lblLog.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$lblLog.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 220)
$lblLog.Location  = New-Object System.Drawing.Point(20, 430)
$lblLog.Size      = New-Object System.Drawing.Size(590, 18)
$form.Controls.Add($lblLog)

$logBox = New-Object System.Windows.Forms.RichTextBox
$logBox.Location    = New-Object System.Drawing.Point(20, 452)
$logBox.Size        = New-Object System.Drawing.Size(590, 88)
$logBox.BackColor   = [System.Drawing.Color]::FromArgb(10, 10, 18)
$logBox.ForeColor   = [System.Drawing.Color]::FromArgb(170, 170, 195)
$logBox.BorderStyle = "FixedSingle"
$logBox.Font        = New-Object System.Drawing.Font("Consolas", 8.5)
$logBox.ReadOnly    = $true
$logBox.ScrollBars  = "Vertical"
$form.Controls.Add($logBox)

# --- BOTAO INSTALAR ---
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text      = "INSTALAR / ATUALIZAR"
$btnInstall.Location  = New-Object System.Drawing.Point(20, 548)
$btnInstall.Size      = New-Object System.Drawing.Size(200, 36)
$btnInstall.FlatStyle = "Flat"
$btnInstall.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(50, 130, 255)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(25, 80, 190)
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.Font      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnInstall.Cursor    = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnInstall)

# --- BOTAO ABRIR PASTA ---
$btnOpenDir = New-Object System.Windows.Forms.Button
$btnOpenDir.Text      = "Abrir Pasta"
$btnOpenDir.Location  = New-Object System.Drawing.Point(232, 548)
$btnOpenDir.Size      = New-Object System.Drawing.Size(120, 36)
$btnOpenDir.FlatStyle = "Flat"
$btnOpenDir.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(55, 70, 95)
$btnOpenDir.BackColor = [System.Drawing.Color]::FromArgb(30, 40, 60)
$btnOpenDir.ForeColor = [System.Drawing.Color]::White
$btnOpenDir.Cursor    = [System.Windows.Forms.Cursors]::Hand
$btnOpenDir.Add_Click({
    if (Test-Path $INSTALL_DIR) {
        Start-Process "explorer.exe" $INSTALL_DIR
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Pasta ainda nao criada. Execute a instalacao primeiro.",
            "Aviso", "OK", "Warning"
        )
    }
})
$form.Controls.Add($btnOpenDir)

# --- BOTAO FECHAR ---
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text      = "Fechar"
$btnClose.Location  = New-Object System.Drawing.Point(520, 548)
$btnClose.Size      = New-Object System.Drawing.Size(90, 36)
$btnClose.FlatStyle = "Flat"
$btnClose.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(75, 45, 45)
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(55, 28, 28)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.Cursor    = [System.Windows.Forms.Cursors]::Hand
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

# =============================================================================
# LOGICA DO BOTAO INSTALAR
# =============================================================================
$btnInstall.Add_Click({
    # Verifica se o nanoCAD esta rodando
    if (Get-Process -Name "nCad", "nanoCAD" -ErrorAction SilentlyContinue) {
        [System.Windows.Forms.MessageBox]::Show(
            "O nanoCAD esta aberto!`n`nPor favor, FECHE o nanoCAD antes de prosseguir com a instalacao.`nSe o nanoCAD permanecer aberto, os scripts nao serao carregados automaticamente.",
            "Aviso: nanoCAD Aberto",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return
    }

    $logBox.Clear()

    # Diretorio fonte
    $srcDir = $GLOBAL_SRC_DIR

    # Scripts selecionados
    $selectedScripts = @()
    for ($i = 0; $i -lt $chkList.Items.Count; $i++) {
        if ($chkList.GetItemChecked($i)) {
            $selectedScripts += $chkList.Items[$i].ToString()
        }
    }

    if ($selectedScripts.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Selecione ao menos um script para instalar.",
            "Aviso", "OK", "Warning"
        )
        return
    }

    $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(90, 170, 255)
    $logBox.AppendText("Origem : $srcDir`n")
    $logBox.AppendText("Destino: $INSTALL_DIR`n")
    $logBox.AppendText("------------------------------------------------`n")

    # Garante registro e pasta de instalacao
    if (-not (Test-Path $REG_BASE)) {
        New-Item -Path $REG_BASE -Force | Out-Null
    }
    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }

    $ok = 0; $fail = 0; $skip = 0

    foreach ($script in $selectedScripts) {
        $src  = Join-Path $srcDir $script
        $dest = Join-Path $INSTALL_DIR $script

        if (-not (Test-Path $src)) {
            $logBox.SelectionColor = [System.Drawing.Color]::Orange
            $logBox.AppendText("  [AVISO]  $script - nao encontrado na origem`n")
            $skip++
            continue
        }

        try {
            Copy-Item -Path $src -Destination $dest -Force
            Register-Script $dest

            $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(70, 210, 110)
            $logBox.AppendText("  [OK]     $script`n")
            $ok++
        } catch {
            $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(230, 80, 70)
            $logBox.AppendText("  [ERRO]   $script -> $($_.Exception.Message)`n")
            $fail++
        }
    }

    Reindex-StartupApps

    # Salva data/hora como versao
    $ver = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    Write-InstalledVersion $ver

    $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(140, 140, 165)
    $logBox.AppendText("------------------------------------------------`n")
    $logBox.SelectionColor = [System.Drawing.Color]::FromArgb(90, 170, 255)
    $logBox.AppendText("Resultado: $ok instalado(s) | $skip pulado(s) | $fail erro(s)`n")

    # Atualiza label de versao
    $lblVer.Text      = "Versao instalada: $ver"
    $lblVer.ForeColor = [System.Drawing.Color]::FromArgb(80, 210, 130)

    if ($ok -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Instalacao concluida com sucesso!`n`n$ok script(s) instalado(s).`n`nReinicie o NanoCAD para ativar os comandos.",
            "Sucesso",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
})

# =============================================================================
# EXIBIR FORMULARIO
# =============================================================================
[void]$form.ShowDialog()
