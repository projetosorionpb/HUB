"""
add_module.py — Script interativo para cadastrar novos módulos no Hub de Engenharia.

Uso:
    python scripts/add_module.py
"""
import json
import os
import sys
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "manifest.json"
MODULES_DIR = ROOT / "modules"

# Cores recomendadas para os cards
RECOMENDED_COLORS = [
    ("#ef4444", "Vermelho (Ex: Automação CAD)"),
    ("#00d4ff", "Ciano/Azul Claro (Ex: Substituidor)"),
    ("#ff8c00", "Laranja (Ex: Conversor PDF)"),
    ("#a855f7", "Roxo (Ex: Gerenciador Obras)"),
    ("#22c55e", "Verde"),
    ("#3b82f6", "Azul Escuro"),
    ("#eab308", "Amarelo"),
]

# SVGs Padrão conforme o tipo de módulo (com placeholder para a cor)
DEFAULT_SVGS = {
    "exe": (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">'
        '<rect x="8" y="8" width="48" height="48" rx="6" fill="{color}" opacity="0.85"/>'
        '<path d="M20 20 L44 20 M20 32 L38 32 M20 44 L32 44" stroke="#ffffff" stroke-width="4" stroke-linecap="round"/>'
        '</svg>'
    ),
    "bat": (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">'
        '<rect x="6" y="10" width="52" height="44" rx="4" fill="#1e1e1e" stroke="{color}" stroke-width="3"/>'
        '<path d="M16 24 L24 32 L16 40" stroke="{color}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'
        '<line x1="28" y1="40" x2="44" y2="40" stroke="{color}" stroke-width="4" stroke-linecap="round"/>'
        '</svg>'
    ),
    "html": (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">'
        '<path d="M16 20 L26 32 L16 44" stroke="{color}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'
        '<path d="M48 20 L38 32 L48 44" stroke="{color}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'
        '<line x1="36" y1="16" x2="28" y2="48" stroke="{color}" stroke-width="4" stroke-linecap="round"/>'
        '</svg>'
    ),
    "web": (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">'
        '<circle cx="32" cy="32" r="22" stroke="{color}" stroke-width="3"/>'
        '<path d="M10 32 H54 M32 10 C38 16 40 24 40 32 C40 40 38 48 32 54 C26 48 24 40 24 32 C24 24 26 16 32 10 Z" stroke="{color}" stroke-width="2.5" fill="none"/>'
        '</svg>'
    )
}

def clean_name(text: str) -> str:
    """Converte strings com acento e espaço para snake_case limpo."""
    nfkd = unicodedata.normalize('NFKD', text)
    text_ascii = nfkd.encode('ASCII', 'ignore').decode('ASCII')
    clean = re.sub(r'[^a-zA-Z0-9\s_-]', '', text_ascii)
    clean = clean.strip().lower()
    return re.sub(r'[\s-]+', '_', clean)

def get_suggested_port(manifest: dict) -> int:
    """Encontra uma porta TCP disponível a partir de 5000."""
    ports = []
    modules = manifest.get("modules", {})
    for mod_cfg in modules.values():
        port = mod_cfg.get("port")
        if port:
            ports.append(port)
    
    suggested = 5000
    while suggested in ports or suggested == 5000:
        if suggested not in ports and suggested != 5000:
            break
        suggested += 1
        # Evita portas comuns
        if suggested in [5000, 5077]: # 5077 é usado pelo PDF, 5000 pelo Bloco
            suggested += 1
    return suggested

def main():
    print("=" * 60)
    print("  Hub de Engenharia — Assistente de Novo Programa")
    print("=" * 60)

    # 1. Carrega manifest.json
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
            manifest = json.load(f)
    except Exception as e:
        print(f"[ERRO] Falha ao carregar manifest.json: {e}")
        sys.exit(1)

    # 2. Pergunta o nome visual da ferramenta
    display_name = ""
    while not display_name.strip():
        display_name = input("\n1. Nome de Exibição (ex: Conversor de Planilhas): ")
    
    # 3. Gera o ID do módulo em snake_case
    suggested_id = clean_name(display_name)
    module_id = input(f"2. ID do Módulo (Pressione Enter para usar '{suggested_id}'): ").strip()
    if not module_id:
        module_id = suggested_id

    # Verifica se já existe
    if module_id in manifest.get("modules", {}):
        overwrite = input(f"\n⚠️  O módulo '{module_id}' já está cadastrado no manifest.json! Sobrescrever? (s/n): ").strip().lower()
        if overwrite != 's':
            print("Operação cancelada.")
            sys.exit(0)

    # 4. Descrição
    description = input("3. Descrição Curta (ex: Organiza colunas e exporta em XLS): ").strip()
    if not description:
        description = f"Ferramenta {display_name}."

    # 5. Tipo
    print("\n4. Tipo de Execução:")
    print("  [exe]  - Programa Executável (.exe standalone com backend embutido)")
    print("  [bat]  - Script em lote do Windows (.bat)")
    print("  [html] - Página web local estática (.html)")
    print("  [web]  - Link para site externo (URL de nuvem)")
    
    m_type = ""
    while m_type not in ["exe", "bat", "html", "web"]:
        m_type = input("Escolha o tipo (exe/bat/html/web): ").strip().lower()

    # 6. Parâmetros específicos de tipo
    exe_name = None
    port = None
    entry = ""

    if m_type == "exe":
        entry = input("\n5. Nome do arquivo executável principal (ex: Gerador.exe): ").strip()
        while not entry:
            entry = input("Digite o nome do executável: ").strip()
        exe_name = entry
        
        # Sugere porta
        sug_port = get_suggested_port(manifest)
        port_input = input(f"6. Porta TCP para o backend (Pressione Enter para usar {sug_port}): ").strip()
        port = int(port_input) if port_input.isdigit() else sug_port

    elif m_type == "bat":
        entry = input("\n5. Nome do script .bat de entrada (ex: INSTALAR_SCRIPTS.bat): ").strip()
        while not entry:
            entry = input("Digite o nome do script .bat: ").strip()

    elif m_type == "html":
        entry = input("\n5. Nome do arquivo HTML de entrada (ex: index.html): ").strip()
        while not entry:
            entry = input("Digite o nome do arquivo HTML: ").strip()

    elif m_type == "web":
        entry = input("\n5. URL do site (ex: https://meusite.com): ").strip()
        while not entry:
            entry = input("Digite a URL do site: ").strip()

    # 7. Escolha de cor
    print("\n6. Escolha uma Cor para o Card:")
    for idx, (hex_code, name) in enumerate(RECOMENDED_COLORS):
        print(f"  [{idx + 1}] {name} -> {hex_code}")
    color_choice = input("Escolha uma opção (1-7) ou digite um código Hexadecimal (ex: #ff0055): ").strip()
    
    color = "#4f46e5"  # cor padrão
    if color_choice.isdigit() and 1 <= int(color_choice) <= len(RECOMENDED_COLORS):
        color = RECOMENDED_COLORS[int(color_choice) - 1][0]
    elif color_choice.startswith("#") and len(color_choice) == 7:
        color = color_choice

    # 8. Define o ícone SVG básico
    icon_svg = DEFAULT_SVGS[m_type].format(color=color)

    # 9. Constrói o dicionário de dados
    module_data = {
        "version": "1.0.0",
        "display_name": display_name,
        "description": description,
        "type": m_type,
        "exe_name": exe_name,
        "port": port,
        "entry": entry,
        "color": color,
        "icon_svg": icon_svg,
        "download_url": ""
    }

    # 10. Atualiza manifest.json
    manifest.setdefault("modules", {})[module_id] = module_data
    try:
        with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2, ensure_ascii=False)
        print(f"\n[OK] Módulo '{module_id}' adicionado ao manifest.json!")
    except Exception as e:
        print(f"[ERRO] Falha ao atualizar manifest.json: {e}")
        sys.exit(1)

    # 11. Cria pasta local e arquivos template se não for tipo web
    if m_type != "web":
        mod_dir = MODULES_DIR / module_id
        mod_dir.mkdir(parents=True, exist_ok=True)
        print(f"[OK] Pasta criada localmente em: {mod_dir}")
        
        entry_path = mod_dir / entry
        if not entry_path.exists():
            if m_type == "html":
                with open(entry_path, "w", encoding="utf-8") as f:
                    f.write(f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>{display_name}</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            background-color: #0f1724;
            color: white;
            text-align: center;
            padding: 50px;
        }}
        h1 {{ color: {color}; }}
    </style>
</head>
<body>
    <h1>{display_name}</h1>
    <p>{description}</p>
    <p>Esta página foi gerada automaticamente. Coloque o código da sua ferramenta aqui!</p>
</body>
</html>""")
            elif m_type == "bat":
                with open(entry_path, "w", encoding="utf-8") as f:
                    f.write(f"""@echo off
echo ========================================================
echo   Iniciando: {display_name}
echo ========================================================
echo.
echo Modulo: {module_id}
echo Categoria: {description}
echo.
echo Coloque os comandos do seu script aqui!
echo.
pause
""")
            elif m_type == "exe":
                with open(entry_path, "w", encoding="utf-8") as f:
                    f.write("")  # arquivo vazio
                print(f"⚠️  Arquivo executável de simulação criado em: {entry}. Substitua pelo executável real compilado!")

    print("\n" + "=" * 60)
    print("🎉 Módulo criado e cadastrado com sucesso!")
    print("=" * 60)
    print("Próximos passos:")
    if m_type != "web":
        print(f"  1. Vá até a pasta: modules/{module_id}")
        print(f"  2. Coloque os arquivos reais do seu programa lá dentro.")
    print("  3. Quando estiver pronto para subir para os usuários, execute:")
    print("     python scripts/build_release.py")
    print("  4. Crie a release no GitHub correspondente e publique os novos arquivos!")
    print("=" * 60)

if __name__ == "__main__":
    main()
