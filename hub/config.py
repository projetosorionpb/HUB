"""
config.py — Configurações centrais do Hub de Engenharia.

Edite as constantes abaixo para refletir o seu ambiente.
"""
import os
import sys

# ---------------------------------------------------------------------------
# GitHub — preencha quando criar o repositório
# ---------------------------------------------------------------------------
GITHUB_USER = "seu_usuario"
GITHUB_REPO = "hub-engenharia"
GITHUB_API_BASE = f"https://api.github.com/repos/{GITHUB_USER}/{GITHUB_REPO}"

# ---------------------------------------------------------------------------
# Caminhos — RELATIVOS ao hub para funcionar em rede compartilhada
# ---------------------------------------------------------------------------
# Diretório raiz do hub (onde está o .exe ou o script hub/main.py)
if getattr(sys, 'frozen', False):
    # Rodando como executável PyInstaller
    _HUB_ROOT = os.path.dirname(sys.executable)
else:
    # Rodando em modo desenvolvimento: hub/config.py → dois níveis acima = raiz
    _HUB_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Pasta modules/ fica sempre ao lado do hub (relativa)
MODULES_DIR = os.path.join(_HUB_ROOT, "modules")

# Arquivo manifest local (junto ao executável / ao hub)
MANIFEST_PATH = os.path.join(_HUB_ROOT, "manifest.json")

# ---------------------------------------------------------------------------
# Ferramentas disponíveis
# ---------------------------------------------------------------------------
TOOLS: dict[str, dict] = {
    "substituidor_blocos": {
        "display_name": "Substituidor de Blocos",
        "description": "Substitui blocos em arquivos de projeto de forma automatizada.",
        "type": "exe",            # exe standalone (abre browser automaticamente)
        "exe_name": "Substituidor_Blocos_DXF.exe",
        "port": 5000,             # usado apenas para checar duplicata
        "entry": "Substituidor_Blocos_DXF.exe",
        # Ícone SVG embutido (cor: ciano)
        "icon_svg": """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">
  <rect x="4"  y="4"  width="24" height="24" rx="4" fill="#00d4ff" opacity="0.9"/>
  <rect x="36" y="4"  width="24" height="24" rx="4" fill="#00d4ff" opacity="0.6"/>
  <rect x="4"  y="36" width="24" height="24" rx="4" fill="#00d4ff" opacity="0.6"/>
  <rect x="36" y="36" width="24" height="24" rx="4" fill="#00d4ff" opacity="0.9"/>
  <line x1="28" y1="16" x2="36" y2="16" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>
  <line x1="16" y1="28" x2="16" y2="36" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>
  <line x1="48" y1="28" x2="48" y2="36" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>
  <line x1="28" y1="48" x2="36" y2="48" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>
</svg>""",
        "color": "#00d4ff",
    },
    "conversor_pdf": {
        "display_name": "Conversor PDF",
        "description": "Converte e processa documentos para o formato PDF.",
        "type": "exe",            # exe standalone (abre browser automaticamente)
        "exe_name": "Conversor_PDF_para_DWG.exe",
        "port": 5077,             # usado apenas para checar duplicata
        "entry": "Conversor_PDF_para_DWG.exe",
        "icon_svg": """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">
  <rect x="10" y="4" width="36" height="44" rx="4" fill="#ff8c00" opacity="0.85"/>
  <rect x="10" y="4" width="36" height="44" rx="4" stroke="#ff8c00" stroke-width="1.5"/>
  <path d="M34 4 L46 16 L34 16 Z" fill="#0f1724"/>
  <path d="M34 4 L34 16 L46 16" fill="none" stroke="#ff8c00" stroke-width="1.5"/>
  <rect x="16" y="22" width="24" height="3" rx="1.5" fill="#0f1724" opacity="0.7"/>
  <rect x="16" y="29" width="20" height="3" rx="1.5" fill="#0f1724" opacity="0.7"/>
  <rect x="16" y="36" width="16" height="3" rx="1.5" fill="#0f1724" opacity="0.7"/>
  <circle cx="46" cy="48" r="12" fill="#0f1724"/>
  <circle cx="46" cy="48" r="12" fill="#ff8c00" opacity="0.2" stroke="#ff8c00" stroke-width="1.5"/>
  <text x="46" y="53" text-anchor="middle" font-size="10" font-weight="bold" fill="#ff8c00" font-family="Arial">PDF</text>
</svg>""",
        "color": "#ff8c00",
    },
    "analise_qualidade": {
        "display_name": "Análise de Qualidade",
        "description": "Dashboard de análise e controle de qualidade dos projetos.",
        "type": "html",
        "port": None,
        "entry": "index.html",
        "exe_name": None,
        "icon_svg": """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">
  <rect x="6"  y="36" width="12" height="22" rx="3" fill="#00e676" opacity="0.7"/>
  <rect x="22" y="24" width="12" height="34" rx="3" fill="#00e676" opacity="0.85"/>
  <rect x="38" y="12" width="12" height="46" rx="3" fill="#00e676"/>
  <polyline points="10,34 26,22 42,10 56,6" stroke="#00e676" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" fill="none" opacity="0.5"/>
  <path d="M44 18 L52 10 M52 10 L44 10 M52 10 L52 18" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>""",
        "color": "#00e676",
    },
    "gerenciador_obras": {
        "display_name": "Gerenciador de Obras",
        "description": "Kanban de gestão e acompanhamento de obras em campo.",
        "type": "html",
        "port": None,
        "entry": "index.html",
        "exe_name": None,
        "icon_svg": """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">
  <rect x="4"  y="20" width="16" height="38" rx="3" fill="#a855f7" opacity="0.7"/>
  <rect x="24" y="20" width="16" height="38" rx="3" fill="#a855f7" opacity="0.85"/>
  <rect x="44" y="20" width="16" height="38" rx="3" fill="#a855f7" opacity="0.5"/>
  <rect x="7"  y="24" width="10" height="7" rx="2" fill="#ffffff" opacity="0.8"/>
  <rect x="7"  y="35" width="10" height="7" rx="2" fill="#ffffff" opacity="0.5"/>
  <rect x="27" y="24" width="10" height="7" rx="2" fill="#ffffff" opacity="0.8"/>
  <rect x="27" y="35" width="10" height="7" rx="2" fill="#ffffff" opacity="0.8"/>
  <rect x="27" y="46" width="10" height="7" rx="2" fill="#ffffff" opacity="0.5"/>
  <rect x="47" y="24" width="10" height="7" rx="2" fill="#ffffff" opacity="0.8"/>
  <path d="M8 14 Q32 4 56 14" stroke="#a855f7" stroke-width="3" stroke-linecap="round" fill="none"/>
</svg>""",
        "color": "#a855f7",
    },
}

# Versão atual do hub
HUB_VERSION = "1.0.0"
