"""
launcher.py — Responsável por abrir os módulos.

Tipos de módulo suportados:
  - exe   : Executável standalone (Flask embutido + abre browser sozinho)
  - html  : Arquivo HTML estático — abre no browser padrão
  - flask : Flask via `python app.py` (modo dev, requer Python instalado)

Para distribuição em rede sem Python, use sempre módulos do tipo `exe`.
"""
import os
import sys
import socket
import webbrowser
import subprocess
import time
from pathlib import Path

from hub.config import MODULES_DIR

# Registro de processos ativos: module_name -> subprocess.Popen
_running_processes: dict[str, subprocess.Popen] = {}


def _module_path(module_name: str) -> Path:
    return Path(MODULES_DIR) / module_name


def open_tool(module_name: str, tool_cfg: dict) -> tuple[bool, str]:
    """
    Abre a ferramenta indicada.
    Retorna (sucesso: bool, mensagem: str).
    """
    kind = tool_cfg.get("type", "exe")
    if kind == "exe":
        return _open_exe(module_name, tool_cfg)
    elif kind == "html":
        return _open_html(module_name, tool_cfg)
    else:  # flask (modo dev com Python)
        return _open_flask_dev(module_name, tool_cfg)


# ──────────────────────────────────────────────────────────────────────────────
# Tipo EXE — executável standalone (sem Python na máquina do usuário)
# ──────────────────────────────────────────────────────────────────────────────
def _open_exe(module_name: str, cfg: dict) -> tuple[bool, str]:
    """
    Lança o executável do módulo.
    O próprio exe é responsável por iniciar o servidor e abrir o browser.
    O hub apenas evita abrir múltiplas instâncias verificando a porta.
    """
    exe_name = cfg.get("exe_name") or cfg.get("entry")
    exe_path = _module_path(module_name) / exe_name

    if not exe_path.exists():
        return False, (
            f"Módulo não encontrado:\n{exe_path}\n\n"
            f"Copie a pasta do módulo para:\n{_module_path(module_name)}"
        )

    # Verifica processo já ativo
    proc = _running_processes.get(module_name)
    if proc and proc.poll() is None:
        port = cfg.get("port")
        if port and _is_port_open(port):
            webbrowser.open(f"http://127.0.0.1:{port}")
            return True, f"{cfg['display_name']} já está em execução."
        # Processo existe mas porta não responde — encerra e reinicia
        proc.terminate()

    try:
        proc = subprocess.Popen(
            [str(exe_path)],
            cwd=str(exe_path.parent),
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        _running_processes[module_name] = proc
        return True, f"{cfg['display_name']} iniciado."
    except Exception as e:
        return False, f"Erro ao iniciar {cfg['display_name']}:\n{e}"


# ──────────────────────────────────────────────────────────────────────────────
# Tipo HTML — arquivo estático
# ──────────────────────────────────────────────────────────────────────────────
def _open_html(module_name: str, cfg: dict) -> tuple[bool, str]:
    """Abre um arquivo HTML estático no browser padrão."""
    entry_path = _module_path(module_name) / cfg["entry"]

    if not entry_path.exists():
        return False, (
            f"Módulo não encontrado:\n{entry_path}\n\n"
            f"Copie a pasta do módulo para:\n{_module_path(module_name)}"
        )

    try:
        webbrowser.open(entry_path.as_uri())
        return True, f"{cfg['display_name']} aberto."
    except Exception as e:
        return False, f"Erro ao abrir {cfg['display_name']}:\n{e}"


# ──────────────────────────────────────────────────────────────────────────────
# Tipo FLASK (dev) — requer Python instalado, apenas para desenvolvimento
# ──────────────────────────────────────────────────────────────────────────────
def _open_flask_dev(module_name: str, cfg: dict) -> tuple[bool, str]:
    """Inicia Flask via `python app.py` (modo desenvolvimento)."""
    port = cfg["port"]
    url = f"http://127.0.0.1:{port}"

    proc = _running_processes.get(module_name)
    if proc and proc.poll() is None:
        webbrowser.open(url)
        return True, f"{cfg['display_name']} já está rodando em {url}"

    module_dir = _module_path(module_name)
    entry = module_dir / cfg["entry"]

    if not entry.exists():
        return False, f"Módulo não encontrado:\n{entry}"

    try:
        proc = subprocess.Popen(
            [sys.executable, str(entry)],
            cwd=str(module_dir),
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        _running_processes[module_name] = proc
        time.sleep(1.5)
        webbrowser.open(url)
        return True, f"{cfg['display_name']} iniciado em {url}"
    except Exception as e:
        return False, f"Erro ao iniciar {cfg['display_name']}:\n{e}"


# ──────────────────────────────────────────────────────────────────────────────
# Utilitários
# ──────────────────────────────────────────────────────────────────────────────
def _is_port_open(port: int, host: str = "127.0.0.1", timeout: float = 0.5) -> bool:
    """Verifica se uma porta TCP está em uso (servidor respondendo)."""
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (OSError, ConnectionRefusedError):
        return False


def stop_tool(module_name: str) -> None:
    """Encerra o processo de um módulo, se estiver ativo."""
    proc = _running_processes.get(module_name)
    if proc and proc.poll() is None:
        proc.terminate()
    _running_processes.pop(module_name, None)


def stop_all() -> None:
    """Encerra todos os processos ativos ao fechar o hub."""
    for name in list(_running_processes.keys()):
        stop_tool(name)
