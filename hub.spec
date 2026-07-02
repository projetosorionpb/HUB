# -*- mode: python ; coding: utf-8 -*-
"""
hub.spec — Configuração do PyInstaller para gerar dist/HubEngenharia.exe

Uso:
    pyinstaller hub.spec
"""

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
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
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
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    # icon='hub/assets/icon.ico',   # Descomente quando tiver um .ico
)
