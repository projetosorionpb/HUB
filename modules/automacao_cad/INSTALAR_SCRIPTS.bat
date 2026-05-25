@echo off
:: ============================================================
:: INSTALADOR DE SCRIPTS LISP - NanoCAD 5
:: Clique duplo para instalar ou atualizar os scripts
:: ============================================================
chcp 65001 >nul 2>&1
title Instalador Scripts LISP - NanoCAD 5

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALAR_SCRIPTS.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERRO] Falha ao executar o instalador.
    echo Pressione qualquer tecla para sair...
    pause >nul
)
