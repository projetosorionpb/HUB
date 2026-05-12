# -*- mode: python ; coding: utf-8 -*-
"""
hub.spec — Configuração do PyInstaller para gerar dist/HubEngenharia.exe

Uso:
    pyinstaller hub.spec
"""

block_cipher = None

a = Analysis(
    ['hub/main.py'],
    pathex=['.'],
    binaries=[],
    datas=[
        ('manifest.json', '.'),   # manifest junto ao executável
    ],
    hiddenimports=[
        'PyQt6.QtSvg',
        'PyQt6.QtSvgWidgets',
        'PyQt6.QtXml',
        'packaging.version',
        'packaging.specifiers',
        'packaging.requirements',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='HubEngenharia',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,          # Sem janela de console no Windows
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    # icon='hub/assets/icon.ico',   # Descomente quando tiver um .ico
)
