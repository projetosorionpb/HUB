"""
config.py — Configurações centrais do Hub de Engenharia.
"""
import os
import sys

# ---------------------------------------------------------------------------
# GitHub
# ---------------------------------------------------------------------------
GITHUB_USER = "projetosorionpb"
GITHUB_REPO = "HUB"
GITHUB_API_BASE = f"https://api.github.com/repos/{GITHUB_USER}/{GITHUB_REPO}"

# URL do manifest.json hospedado na branch main (raw)
MANIFEST_RAW_URL = (
    f"https://raw.githubusercontent.com/{GITHUB_USER}/{GITHUB_REPO}/main/manifest.json"
)

# ---------------------------------------------------------------------------
# Caminhos — relativos ao hub para funcionar em rede compartilhada
# ---------------------------------------------------------------------------
if getattr(sys, 'frozen', False):
    # Rodando como executável PyInstaller
    _HUB_ROOT = os.path.dirname(sys.executable)
else:
    # Modo desenvolvimento: hub/config.py → dois níveis acima = raiz
    _HUB_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MODULES_DIR = os.path.join(_HUB_ROOT, "modules")
MANIFEST_PATH = os.path.join(_HUB_ROOT, "manifest.json")

# Versão atual do hub
HUB_VERSION = "1.0.0"
