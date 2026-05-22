#Requires -Version 5.0
# =============================================================================
# ATUALIZADOR AUTOMATICO - Scripts LISP NanoCAD 5
# Uso: ATUALIZAR_SCRIPTS.ps1 [-GitHubRepo "usuario/repositorio"] [-Silent] [-Force]
#
# Parametros:
#   -GitHubRepo  : Repositorio GitHub (ex: "meuusuario/meu-repo")
#   -Silent      : Nao exibe janelas, apenas notifica se houver atualizacao
#   -Force       : Forca reinstalacao mesmo sem nova versao
# =============================================================================

param(
    [string]$GitHubRepo = "SEU_USUARIO/SEU_REPOSITORIO",  # <<< CONFIGURE AQUI
    [switch]$Silent,
    [switch]$Force
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# =============================================================================
# CONFIGURACOES (devem ser iguais as do INSTALAR_SCRIPTS.ps1)
# =============================================================================
$INSTALL_DIR  = Join-Path $env:LOCALAPPDATA "NanoCAD_Scripts_CAD"
$VERSION_FILE = Join-Path $INSTALL_DIR "version.txt"
$TEMP_DIR     = Join-Path $env:TEMP "NanoCAD_Scripts_Update"
$GITHUB_API   = "https://api.github.com/repos/$GitHubRepo/releases/latest"



$REG_BASE      = "HKCU:\SOFTWARE\Nanosoft AS\nanoCAD Int\5.0\Profile\Appload\Startup"
$ENABLED_VALUE = [byte[]](5,0,0,0,1,0,0,0)

# =============================================================================
# FUNCOES
# =============================================================================

function Get-InstalledVersion {
    if (Test-Path $VERSION_FILE) {
        return (Get-Content $VERSION_FILE -Raw).Trim()
    }
    return $null
}

function Get-LatestRelease {
    try {
        $headers  = @{ "User-Agent" = "NanoCAD-Scripts-Updater" }
        $response = Invoke-RestMethod -Uri $GITHUB_API -Headers $headers -ErrorAction Stop
        return $response
    } catch {
        return $null
    }
}

function Show-Notification($title, $message) {
    try {
        $balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.Icon            = [System.Drawing.SystemIcons]::Information
        $balloon.BalloonTipTitle = $title
        $balloon.BalloonTipText  = $message
        $balloon.BalloonTipIcon  = "Info"
        $balloon.Visible         = $true
        $balloon.ShowBalloonTip(6000)
        Start-Sleep -Milliseconds 700
        $balloon.Dispose()
    } catch {}
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
            if ([System.IO.Path]::GetFileName($props.Loader) -ieq $scriptName) {
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

function Show-UpdateDialog($installedVer, $latestVer, $releaseNotes) {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text            = "Atualizacao Disponivel - Scripts LISP NanoCAD"
    $dlg.ClientSize      = New-Object System.Drawing.Size(510, 350)
    $dlg.StartPosition   = "CenterScreen"
    $dlg.BackColor       = [System.Drawing.Color]::FromArgb(18, 18, 30)
    $dlg.ForeColor       = [System.Drawing.Color]::White
    $dlg.Font            = New-Object System.Drawing.Font("Segoe UI", 9)
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.MaximizeBox     = $false

    $lbl1 = New-Object System.Windows.Forms.Label
    $lbl1.Text      = "Nova versao disponivel!"
    $lbl1.Font      = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    $lbl1.ForeColor = [System.Drawing.Color]::FromArgb(90, 195, 255)
    $lbl1.Location  = New-Object System.Drawing.Point(20, 18)
    $lbl1.Size      = New-Object System.Drawing.Size(470, 28)
    $dlg.Controls.Add($lbl1)

    $verText = if ($installedVer) { "Instalada: $installedVer     Nova: $latestVer" } else { "Nova versao: $latestVer  (nenhuma instalada)" }
    $lbl2 = New-Object System.Windows.Forms.Label
    $lbl2.Text      = $verText
    $lbl2.ForeColor = [System.Drawing.Color]::FromArgb(175, 175, 200)
    $lbl2.Location  = New-Object System.Drawing.Point(20, 52)
    $lbl2.Size      = New-Object System.Drawing.Size(470, 20)
    $dlg.Controls.Add($lbl2)

    $sep = New-Object System.Windows.Forms.Panel
    $sep.Location  = New-Object System.Drawing.Point(20, 78)
    $sep.Size      = New-Object System.Drawing.Size(470, 1)
    $sep.BackColor = [System.Drawing.Color]::FromArgb(55, 55, 80)
    $dlg.Controls.Add($sep)

    $lblNotes = New-Object System.Windows.Forms.Label
    $lblNotes.Text      = "Notas da versao:"
    $lblNotes.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblNotes.ForeColor = [System.Drawing.Color]::FromArgb(195, 195, 215)
    $lblNotes.Location  = New-Object System.Drawing.Point(20, 88)
    $lblNotes.Size      = New-Object System.Drawing.Size(200, 20)
    $dlg.Controls.Add($lblNotes)

    $txtNotes = New-Object System.Windows.Forms.RichTextBox
    $txtNotes.Text        = if ($releaseNotes) { $releaseNotes } else { "Sem notas de versao disponiveis." }
    $txtNotes.ReadOnly    = $true
    $txtNotes.BackColor   = [System.Drawing.Color]::FromArgb(26, 26, 42)
    $txtNotes.ForeColor   = [System.Drawing.Color]::FromArgb(195, 195, 215)
    $txtNotes.Location    = New-Object System.Drawing.Point(20, 112)
    $txtNotes.Size        = New-Object System.Drawing.Size(470, 160)
    $txtNotes.BorderStyle = "FixedSingle"
    $dlg.Controls.Add($txtNotes)

    $script:dlgResult = [System.Windows.Forms.DialogResult]::No

    $btnYes = New-Object System.Windows.Forms.Button
    $btnYes.Text      = "Instalar Agora"
    $btnYes.Location  = New-Object System.Drawing.Point(20, 296)
    $btnYes.Size      = New-Object System.Drawing.Size(150, 36)
    $btnYes.FlatStyle = "Flat"
    $btnYes.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(50, 130, 255)
    $btnYes.BackColor = [System.Drawing.Color]::FromArgb(25, 80, 190)
    $btnYes.ForeColor = [System.Drawing.Color]::White
    $btnYes.Font      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnYes.Add_Click({ $script:dlgResult = [System.Windows.Forms.DialogResult]::Yes; $dlg.Close() })
    $dlg.Controls.Add($btnYes)

    $btnNo = New-Object System.Windows.Forms.Button
    $btnNo.Text      = "Lembrar Depois"
    $btnNo.Location  = New-Object System.Drawing.Point(182, 296)
    $btnNo.Size      = New-Object System.Drawing.Size(135, 36)
    $btnNo.FlatStyle = "Flat"
    $btnNo.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(55, 55, 80)
    $btnNo.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 58)
    $btnNo.ForeColor = [System.Drawing.Color]::White
    $btnNo.Add_Click({ $script:dlgResult = [System.Windows.Forms.DialogResult]::No; $dlg.Close() })
    $dlg.Controls.Add($btnNo)

    $btnSkip = New-Object System.Windows.Forms.Button
    $btnSkip.Text      = "Pular Versao"
    $btnSkip.Location  = New-Object System.Drawing.Point(358, 296)
    $btnSkip.Size      = New-Object System.Drawing.Size(132, 36)
    $btnSkip.FlatStyle = "Flat"
    $btnSkip.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(75, 42, 42)
    $btnSkip.BackColor = [System.Drawing.Color]::FromArgb(50, 26, 26)
    $btnSkip.ForeColor = [System.Drawing.Color]::FromArgb(200, 145, 145)
    $btnSkip.Add_Click({ $script:dlgResult = [System.Windows.Forms.DialogResult]::Ignore; $dlg.Close() })
    $dlg.Controls.Add($btnSkip)

    [void]$dlg.ShowDialog()
    return $script:dlgResult
}

function Install-FromDirectory($lspDir, $logLines) {
    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }
    if (-not (Test-Path $REG_BASE)) {
        New-Item -Path $REG_BASE -Force | Out-Null
    }

    $count = 0
    $SCRIPTS = @(Get-ChildItem -Path $lspDir -Filter "*.lsp" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    foreach ($script in $SCRIPTS) {
        $src  = Join-Path $lspDir $script
        $dest = Join-Path $INSTALL_DIR $script
        if (Test-Path $src) {
            Copy-Item $src -Destination $dest -Force
            Register-Script $dest
            $count++
            $logLines.Add("[OK]  $script")
        } else {
            $logLines.Add("[--]  $script (nao encontrado no pacote)")
        }
    }

    Reindex-StartupApps
    return $count
}

function Download-AndInstall($release) {
    $logLines = New-Object System.Collections.Generic.List[string]

    $zipAsset = $release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1

    if (Test-Path $TEMP_DIR) { Remove-Item $TEMP_DIR -Recurse -Force }
    New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null

    if ($zipAsset) {
        $zipPath = Join-Path $TEMP_DIR $zipAsset.name
        Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -UseBasicParsing
    } else {
        $zipPath = Join-Path $TEMP_DIR "source.zip"
        Invoke-WebRequest -Uri $release.zipball_url -OutFile $zipPath -UseBasicParsing
    }

    Expand-Archive -Path $zipPath -DestinationPath $TEMP_DIR -Force

    # Encontra a pasta com os LSPs
    $firstLsp = Get-ChildItem $TEMP_DIR -Recurse -Filter "*.lsp" | Select-Object -First 1
    if (-not $firstLsp) {
        throw "Nenhum arquivo .lsp encontrado no pacote baixado."
    }
    $lspDir = Split-Path $firstLsp.FullName

    $count = Install-FromDirectory $lspDir $logLines

    # Salva tag do release como versao
    $release.tag_name | Set-Content $VERSION_FILE -Encoding UTF8

    return @{ Count = $count; Log = $logLines }
}

# =============================================================================
# FLUXO PRINCIPAL
# =============================================================================

$installedVer = Get-InstalledVersion

Write-Host "Verificando atualizacoes em github.com/$GitHubRepo ..."
$release = Get-LatestRelease

if (-not $release) {
    if (-not $Silent) {
        [System.Windows.Forms.MessageBox]::Show(
            "Nao foi possivel verificar atualizacoes.`n`nVerifique a conexao com a internet ou configure o repositorio GitHub.`n`nRepositorio atual: $GitHubRepo",
            "Erro de Conexao",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
    exit 1
}

$latestVer = $release.tag_name

# Versoes puladas
$skipFile   = Join-Path $INSTALL_DIR "skip_version.txt"
$skippedVer = if (Test-Path $skipFile) { (Get-Content $skipFile -Raw).Trim() } else { "" }

$needsUpdate = ($latestVer -ne $installedVer) -and ($latestVer -ne $skippedVer)

if (-not $needsUpdate -and -not $Force) {
    if (-not $Silent) {
        [System.Windows.Forms.MessageBox]::Show(
            "Voce ja esta na versao mais recente!`n`nVersao instalada: $installedVer",
            "Sem Atualizacoes",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
    exit 0
}

# Modo silencioso: apenas notificacao na bandeja do sistema
if ($Silent) {
    Show-Notification `
        "Atualizacao Disponivel - Scripts NanoCAD" `
        "Nova versao $latestVer disponivel. Execute ATUALIZAR_SCRIPTS.bat para instalar."
    exit 0
}

$dlgResult = Show-UpdateDialog $installedVer $latestVer $release.body

switch ($dlgResult) {
    ([System.Windows.Forms.DialogResult]::Yes) {
        if (Get-Process -Name "nCad", "nanoCAD" -ErrorAction SilentlyContinue) {
            [System.Windows.Forms.MessageBox]::Show(
                "O nanoCAD esta aberto!`n`nPor favor, FECHE o nanoCAD antes de prosseguir com a atualizacao.`nSe o nanoCAD permanecer aberto, os scripts nao serao carregados automaticamente.",
                "Aviso: nanoCAD Aberto",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        try {
            $result = Download-AndInstall $release
            [System.Windows.Forms.MessageBox]::Show(
                "Atualizacao concluida!`n`n$($result.Count) script(s) atualizado(s) para a versao $latestVer.`n`nReinicie o NanoCAD para aplicar as mudancas.",
                "Atualizacao Concluida",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Erro durante a atualizacao:`n`n$($_.Exception.Message)`n`nTente instalar manualmente usando INSTALAR_SCRIPTS.bat.",
                "Erro na Atualizacao",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    ([System.Windows.Forms.DialogResult]::Ignore) {
        $latestVer | Set-Content $skipFile -Encoding UTF8
        Write-Host "Versao $latestVer marcada para pular."
    }
    default {
        Write-Host "Atualizacao adiada pelo usuario."
    }
}
