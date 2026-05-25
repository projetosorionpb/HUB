# -*- coding: utf-8 -*-
"""
admin_hub.py - Assistente Interativo do Hub de Engenharia
"""
import os
import sys
import json
import shutil
import zipfile
import subprocess
import unicodedata
import re
from pathlib import Path

# =========================================================
# CONFIGURAÇÕES E CAMINHOS
# =========================================================
ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "manifest.json"
MODULES_DIR = ROOT / "modules"
DIST_DIR = ROOT / "dist"

# Precisamos do Github correto
GITHUB_USER = "projetosorionpb"
GITHUB_REPO = "HUB"

# Cores e estilos (fallback para caracteres seguros)
RECOMENDED_COLORS = [
    ("#ef4444", "Vermelho (Ex: Automacao CAD)"),
    ("#00d4ff", "Ciano/Azul Claro (Ex: Substituidor)"),
    ("#ff8c00", "Laranja (Ex: Conversor PDF)"),
    ("#a855f7", "Roxo (Ex: Gerenciador Obras)"),
    ("#22c55e", "Verde"),
    ("#3b82f6", "Azul Escuro"),
    ("#eab308", "Amarelo"),
]

DEFAULT_SVGS = {
    "exe": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none"><rect x="8" y="8" width="48" height="48" rx="6" fill="{color}" opacity="0.85"/><path d="M20 20 L44 20 M20 32 L38 32 M20 44 L32 44" stroke="#ffffff" stroke-width="4" stroke-linecap="round"/></svg>',
    "bat": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none"><rect x="6" y="10" width="52" height="44" rx="4" fill="#1e1e1e" stroke="{color}" stroke-width="3"/><path d="M16 24 L24 32 L16 40" stroke="{color}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/><line x1="28" y1="40" x2="44" y2="40" stroke="{color}" stroke-width="4" stroke-linecap="round"/></svg>',
    "html": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none"><path d="M16 20 L26 32 L16 44" stroke="{color}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/><path d="M48 20 L38 32 L48 44" stroke="{color}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/><line x1="36" y1="16" x2="28" y2="48" stroke="{color}" stroke-width="4" stroke-linecap="round"/></svg>',
    "web": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none"><circle cx="32" cy="32" r="22" stroke="{color}" stroke-width="3"/><path d="M10 32 H54 M32 10 C38 16 40 24 40 32 C40 40 38 48 32 54 C26 48 24 40 24 32 C24 24 26 16 32 10 Z" stroke="{color}" stroke-width="2.5" fill="none"/></svg>'
}

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def load_manifest():
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[ERRO] Falha ao carregar manifest.json: {e}")
        sys.exit(1)

def save_manifest(manifest):
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

def clean_name(text: str) -> str:
    nfkd = unicodedata.normalize('NFKD', text)
    text_ascii = nfkd.encode('ASCII', 'ignore').decode('ASCII')
    clean = re.sub(r'[^a-zA-Z0-9\s_-]', '', text_ascii)
    return re.sub(r'[\s-]+', '_', clean.strip().lower())

def increment_version(version: str) -> str:
    parts = version.split('.')
    if len(parts) == 3 and parts[-1].isdigit():
        parts[-1] = str(int(parts[-1]) + 1)
        return ".".join(parts)
    return version

# =========================================================
# FUNÇÕES DO MENU
# =========================================================

def adicionar_novo_programa(manifest):
    clear_screen()
    print("="*60)
    print("  [+] ADICIONAR NOVO PROGRAMA")
    print("="*60)
    
    display_name = input("Nome de Exibicao (ex: Gerador de Relatorios): ").strip()
    if not display_name: return

    suggested_id = clean_name(display_name)
    module_id = input(f"ID Interno [{suggested_id}]: ").strip() or suggested_id

    description = input("Descricao Curta: ").strip() or f"Ferramenta {display_name}"
    
    print("\nTipos: [1] exe  [2] bat  [3] html  [4] web")
    tipo_op = input("Escolha o tipo (1-4) [1]: ").strip() or "1"
    m_type = {"1":"exe", "2":"bat", "3":"html", "4":"web"}.get(tipo_op, "exe")

    entry = ""
    if m_type == "exe":
        entry = input("Nome do executavel (ex: Gerador.exe): ").strip()
    elif m_type == "bat":
        entry = input("Nome do script (ex: iniciar.bat): ").strip()
    elif m_type == "html":
        entry = input("Nome do html (ex: index.html): ").strip()
    elif m_type == "web":
        entry = input("URL do site (ex: https://site.com): ").strip()
    
    if not entry: entry = "main"

    print("\nCores Recomendadas:")
    for i, (hexa, nome) in enumerate(RECOMENDED_COLORS):
        print(f"[{i+1}] {nome}")
    cor_op = input("Escolha a cor (1-7) [1]: ").strip() or "1"
    color = RECOMENDED_COLORS[int(cor_op)-1][0] if cor_op.isdigit() and int(cor_op) <= len(RECOMENDED_COLORS) else RECOMENDED_COLORS[0][0]

    module_data = {
        "version": "1.0.0",
        "display_name": display_name,
        "description": description,
        "type": m_type,
        "exe_name": entry if m_type == "exe" else None,
        "port": None,
        "entry": entry,
        "color": color,
        "icon_svg": DEFAULT_SVGS[m_type].format(color=color),
        "download_url": ""
    }

    manifest.setdefault("modules", {})[module_id] = module_data
    save_manifest(manifest)

    # Cria pasta
    if m_type != "web":
        mod_dir = MODULES_DIR / module_id
        mod_dir.mkdir(parents=True, exist_ok=True)
        print(f"\n[OK] Pasta criada: modules/{module_id}")
        print("[!] Lembre-se de colocar os arquivos reais dentro dessa pasta!")

    input("\nPressione ENTER para voltar ao menu...")


def atualizar_programa(manifest):
    clear_screen()
    print("="*60)
    print("  [^] ATUALIZAR VERSAO DE UM PROGRAMA")
    print("="*60)
    
    modules = manifest.get("modules", {})
    if not modules:
        print("Nenhum modulo cadastrado!")
        input("\nPressione ENTER para voltar...")
        return

    mod_list = list(modules.keys())
    for i, mod_id in enumerate(mod_list):
        ver = modules[mod_id].get("version", "0.0.0")
        print(f"[{i+1}] {modules[mod_id].get('display_name', mod_id)} (Versao Atual: {ver})")
    
    escolha = input("\nQual programa deseja atualizar o numero da versao? (0 para cancelar): ").strip()
    if not escolha.isdigit() or int(escolha) == 0 or int(escolha) > len(mod_list):
        return

    mod_id = mod_list[int(escolha)-1]
    current_ver = modules[mod_id].get("version", "1.0.0")
    sug_ver = increment_version(current_ver)

    new_ver = input(f"Nova versao [{sug_ver}]: ").strip() or sug_ver
    modules[mod_id]["version"] = new_ver
    
    save_manifest(manifest)
    print(f"\n[OK] {mod_id} atualizado para a versao {new_ver} no manifest.json!")
    print("[!] Lembre-se de colocar os arquivos novos na pasta antes de empacotar.")
    input("\nPressione ENTER para voltar...")


def empacotar_e_enviar(manifest):
    clear_screen()
    print("="*60)
    print("  [>] EMPACOTAR E ENVIAR PARA O GITHUB")
    print("="*60)

    print("Esta etapa vai:")
    print("1. Zipar todos os modulos da pasta modules/")
    print("2. Atualizar as URLs de download com base na TAG da sua release")
    print("3. Fazer o commit e push para o GitHub automaticamente")
    print()

    tag_release = input("Qual sera a TAG da Release no GitHub? (ex: 1.0.3-Ferramentas): ").strip()
    if not tag_release:
        print("Operacao cancelada.")
        input("\nPressione ENTER para voltar...")
        return

    modules = manifest.get("modules", {})
    DIST_DIR.mkdir(parents=True, exist_ok=True)

    print("\n--- Zipando arquivos ---")
    ignore = {"__pycache__", ".git", ".venv", "venv", ".env", "node_modules"}
    zips_gerados = []

    for name, data in modules.items():
        if data.get("type") == "web": continue
        version = data.get("version", "0.0.0")
        module_dir = Path(MODULES_DIR) / name
        
        if not module_dir.exists():
            print(f"[!] Aviso: Pasta modules/{name} nao encontrada. Pulando...")
            continue
            
        zip_name = f"{name}_v{version}.zip"
        zip_path = DIST_DIR / zip_name
        
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for file_path in module_dir.rglob("*"):
                if any(p in ignore or p.endswith((".pyc", ".pyo")) for p in file_path.parts):
                    continue
                if file_path.is_file():
                    zf.write(file_path, file_path.relative_to(module_dir))
                    
        zips_gerados.append(zip_name)
        print(f" [OK] {zip_name} gerado.")
        
        # Atualiza URL no manifest
        manifest["modules"][name]["download_url"] = f"https://github.com/{GITHUB_USER}/{GITHUB_REPO}/releases/download/{tag_release}/{zip_name}"

    save_manifest(manifest)
    print("\n[OK] manifest.json atualizado com as URLs corretas!")

    print("\n--- Sincronizando com o GitHub ---")
    try:
        subprocess.run(["git", "add", "manifest.json"], cwd=ROOT, check=True)
        subprocess.run(["git", "commit", "-m", f"build: preparacao para release {tag_release}"], cwd=ROOT, check=True)
        subprocess.run(["git", "push", "origin", "main"], cwd=ROOT, check=True)
        print("[OK] Alteracoes enviadas ao GitHub com sucesso!")
    except Exception as e:
        print(f"[ERRO] Ocorreu um erro ao rodar os comandos do git: {e}")

    print("\n" + "="*60)
    print("  QUASE LA! SIGA OS PASSOS FINAIS NO NAVEGADOR:")
    print("="*60)
    print("1. Acesse o link abaixo:")
    print(f"   -> https://github.com/{GITHUB_USER}/{GITHUB_REPO}/releases/new")
    print(f"\n2. Em 'Choose a tag', digite exatamente: {tag_release}")
    print("\n3. Arraste TODOS os arquivos .zip que estao na pasta:")
    print(f"   {DIST_DIR}")
    print("   para dentro da caixinha no final da pagina do GitHub.")
    print("\n4. Clique em 'Publish release'.")
    print("="*60)

    input("\nPressione ENTER para voltar ao menu principal...")

# =========================================================
# MAIN
# =========================================================
def main():
    while True:
        clear_screen()
        manifest = load_manifest()
        print("="*60)
        print("  HUB DE ENGENHARIA - PAINEL DE CONTROLE ANTIBURRO")
        print("="*60)
        print()
        print("  [1] Adicionar NOVO Programa ao Hub")
        print("  [2] Atualizar a VERSAO de um Programa Existente")
        print("  [3] EMPACOTAR tudo e Enviar pro GITHUB")
        print("  [0] Sair")
        print()
        op = input("Escolha uma opcao: ").strip()

        if op == "1":
            adicionar_novo_programa(manifest)
        elif op == "2":
            atualizar_programa(manifest)
        elif op == "3":
            empacotar_e_enviar(manifest)
        elif op == "0":
            break

if __name__ == "__main__":
    main()
