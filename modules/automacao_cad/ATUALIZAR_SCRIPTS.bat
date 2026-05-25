@echo off
:: ============================================================
:: ATUALIZADOR DE SCRIPTS LISP - NanoCAD 5
:: Verifica e baixa a versão mais recente do GitHub
:: ============================================================
chcp 65001 >nul 2>&1
title Atualizador Scripts LISP - NanoCAD 5

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ATUALIZAR_SCRIPTS.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERRO] Falha ao executar o atualizador.
    pause >nul
)
