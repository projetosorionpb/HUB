"""
build_release.py — Empacota cada módulo em um arquivo .zip na pasta dist/
e atualiza os download_url no manifest.json local.

Uso:
    python scripts/build_release.py

Ao final, faça commit do manifest.json atualizado e crie uma Release no GitHub.
"""
import json
import os
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from hub.config import MODULES_DIR, MANIFEST_PATH, GITHUB_USER, GITHUB_REPO

DIST_DIR = ROOT / "dist"

IGNORE_PATTERNS = {
    "__pycache__", ".git", ".venv", "venv", ".env", "node_modules",
}


def should_ignore(name: str) -> bool:
    return name in IGNORE_PATTERNS or name.endswith((".pyc", ".pyo"))


def zip_module(module_name: str, version: str) -> Path | None:
    module_dir = Path(MODULES_DIR) / module_name
    if not module_dir.exists():
        print(f"  [AVISO] Módulo '{module_name}' não encontrado em: {module_dir}")
        return None

    DIST_DIR.mkdir(parents=True, exist_ok=True)
    zip_name = f"{module_name}_v{version}.zip"
    zip_path = DIST_DIR / zip_name

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file_path in module_dir.rglob("*"):
            if any(should_ignore(part) for part in file_path.parts):
                continue
            if file_path.is_file():
                arcname = file_path.relative_to(module_dir)
                zf.write(file_path, arcname)

    size_kb = zip_path.stat().st_size / 1024
    print(f"  ✅  {zip_name}  ({size_kb:.1f} KB)")
    return zip_path


def build_download_url(module_name: str, version: str) -> str:
    """Gera a URL de download do GitHub Releases para este módulo."""
    zip_name = f"{module_name}_v{version}.zip"
    tag = f"v{version}"
    return (
        f"https://github.com/{GITHUB_USER}/{GITHUB_REPO}"
        f"/releases/download/{tag}/{zip_name}"
    )


def main():
    print("=" * 60)
    print("  Hub de Engenharia — Build Release")
    print(f"  Repositório: github.com/{GITHUB_USER}/{GITHUB_REPO}")
    print("=" * 60)

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
            # Atualiza download_url no manifest
            url = build_download_url(name, version)
            manifest["modules"][name]["download_url"] = url
            print(f"       URL   : {url}")

    # Salva manifest com URLs atualizados
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"\n{'=' * 60}")
    print(f"  {len(results)} arquivo(s) gerado(s) em: {DIST_DIR}")
    print(f"  manifest.json atualizado com os download_url.")
    print("=" * 60)
    print("\nPróximos passos:")
    print(f"  1. Crie uma Release no GitHub com a tag correta (ex: v1.0.0).")
    print(f"     → https://github.com/{GITHUB_USER}/{GITHUB_REPO}/releases/new")
    print(f"  2. Faça upload dos .zip gerados em dist/.")
    print(f"  3. Faça commit do manifest.json atualizado na branch main.")
    print(f"     O Hub detectará automaticamente as novidades.\n")


if __name__ == "__main__":
    main()
