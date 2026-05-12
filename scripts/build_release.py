"""
build_release.py — Empacota cada módulo em um arquivo .zip na pasta dist/.

Uso:
    python scripts/build_release.py

Pré-requisitos:
    - Os módulos devem estar em: C:\\Users\\<usuario>\\HubEngenharia\\modules\\
    - O manifest.json deve estar atualizado com as versões corretas.

O script gera um arquivo por módulo:
    dist/<module_name>_v<version>.zip
"""
import json
import os
import sys
import zipfile
from pathlib import Path

# Adiciona a raiz do projeto ao sys.path
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from hub.config import MODULES_DIR, MANIFEST_PATH

DIST_DIR = ROOT / "dist"

# Arquivos/pastas a ignorar no zip
IGNORE_PATTERNS = {
    "__pycache__",
    ".git",
    ".venv",
    "venv",
    "*.pyc",
    "*.pyo",
    ".env",
    "node_modules",
}


def should_ignore(name: str) -> bool:
    if name in IGNORE_PATTERNS:
        return True
    if name.endswith((".pyc", ".pyo")):
        return True
    return False


def zip_module(module_name: str, version: str) -> Path:
    module_dir = Path(MODULES_DIR) / module_name

    if not module_dir.exists():
        print(f"  [AVISO] Módulo '{module_name}' não encontrado em: {module_dir}")
        return None

    DIST_DIR.mkdir(parents=True, exist_ok=True)
    zip_name = f"{module_name}_v{version}.zip"
    zip_path = DIST_DIR / zip_name

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file_path in module_dir.rglob("*"):
            # Ignora arquivos/pastas indesejados
            if any(should_ignore(part) for part in file_path.parts):
                continue
            if file_path.is_file():
                arcname = file_path.relative_to(module_dir)
                zf.write(file_path, arcname)

    size_kb = zip_path.stat().st_size / 1024
    print(f"  ✅  {zip_name}  ({size_kb:.1f} KB)")
    return zip_path


def main():
    print("=" * 60)
    print("  Hub de Engenharia — Build Release")
    print("=" * 60)

    # Lê manifest
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
            manifest = json.load(f)
    except FileNotFoundError:
        print(f"\n[ERRO] manifest.json não encontrado em: {MANIFEST_PATH}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"\n[ERRO] manifest.json inválido: {e}")
        sys.exit(1)

    modules = manifest.get("modules", {})
    if not modules:
        print("[AVISO] Nenhum módulo definido no manifest.json.")
        sys.exit(0)

    print(f"\nModules dir : {MODULES_DIR}")
    print(f"Output dir  : {DIST_DIR}")
    print(f"Módulos     : {len(modules)}\n")

    results = []
    for name, data in modules.items():
        version = data.get("version", "0.0.0")
        print(f"  Empacotando: {data.get('display_name', name)} v{version}")
        path = zip_module(name, version)
        if path:
            results.append(path)

    print(f"\n{'=' * 60}")
    print(f"  {len(results)} arquivo(s) gerado(s) em: {DIST_DIR}")
    print("=" * 60)
    print("\nPróximos passos:")
    print("  1. Crie uma Release no GitHub com a tag correspondente.")
    print("  2. Faça upload de todos os .zip gerados em dist/.")
    print("  3. Atualize os 'download_url' no manifest.json.\n")


if __name__ == "__main__":
    main()
