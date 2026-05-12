"""
updater.py — Verificação e download de atualizações via GitHub Releases.

Fluxo:
  1. Lê o manifest.json local para obter as versões instaladas.
  2. Consulta a GitHub Releases API para obter as versões mais recentes.
  3. Emite sinais PyQt para atualizar a UI com o progresso.
  4. Baixa e extrai os .zip dos módulos desatualizados.
"""
import json
import os
import zipfile
import shutil
from pathlib import Path

import requests
from packaging.version import Version
from PyQt6.QtCore import QThread, pyqtSignal

from hub.config import GITHUB_API_BASE, MODULES_DIR, MANIFEST_PATH


def _load_local_manifest() -> dict:
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"modules": {}}


def _save_local_manifest(data: dict) -> None:
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def check_updates_sync() -> list[dict]:
    """
    Verifica atualizações disponíveis de forma síncrona.
    Retorna lista de módulos com update disponível:
      [{"name": ..., "local": ..., "remote": ..., "download_url": ...}]
    """
    manifest = _load_local_manifest()
    updates = []

    try:
        response = requests.get(
            f"{GITHUB_API_BASE}/releases/latest",
            timeout=10,
            headers={"Accept": "application/vnd.github+json"},
        )
        if response.status_code != 200:
            return []

        release = response.json()
        remote_version = release.get("tag_name", "").lstrip("v")
        assets: list[dict] = release.get("assets", [])

        for module_name, module_data in manifest.get("modules", {}).items():
            local_version = module_data.get("version", "0.0.0")

            try:
                if Version(remote_version) > Version(local_version):
                    # Procura o asset correspondente ao módulo
                    asset_url = next(
                        (a["browser_download_url"] for a in assets
                         if module_name in a["name"] and a["name"].endswith(".zip")),
                        None,
                    )
                    if asset_url:
                        updates.append({
                            "name": module_name,
                            "display_name": module_data.get("display_name", module_name),
                            "local": local_version,
                            "remote": remote_version,
                            "download_url": asset_url,
                        })
            except Exception:
                pass

    except requests.RequestException:
        pass

    return updates


class UpdateWorker(QThread):
    """
    QThread que executa download e instalação de atualizações em background.

    Sinais:
        log(str)        — mensagem de progresso
        progress(int)   — percentual 0-100
        finished(bool)  — True = sucesso, False = erro
    """
    log = pyqtSignal(str)
    progress = pyqtSignal(int)
    finished = pyqtSignal(bool)

    def __init__(self, updates: list[dict], parent=None):
        super().__init__(parent)
        self.updates = updates

    def run(self):
        total = len(self.updates)
        if total == 0:
            self.log.emit("Nenhuma atualização para instalar.")
            self.finished.emit(True)
            return

        manifest = _load_local_manifest()
        success = True

        for idx, update in enumerate(self.updates):
            name = update["name"]
            display = update["display_name"]
            url = update["download_url"]
            remote_ver = update["remote"]

            self.log.emit(f"⬇️  Baixando {display} v{remote_ver}...")
            self.progress.emit(int((idx / total) * 80))

            try:
                # Download
                resp = requests.get(url, timeout=60, stream=True)
                resp.raise_for_status()

                zip_path = Path(MODULES_DIR) / f"{name}_update.zip"
                zip_path.parent.mkdir(parents=True, exist_ok=True)

                with open(zip_path, "wb") as f:
                    for chunk in resp.iter_content(chunk_size=8192):
                        f.write(chunk)

                self.log.emit(f"📦  Instalando {display}...")

                # Extração
                module_dir = Path(MODULES_DIR) / name
                backup_dir = Path(MODULES_DIR) / f"{name}_backup"

                # Backup do módulo atual
                if module_dir.exists():
                    if backup_dir.exists():
                        shutil.rmtree(backup_dir)
                    shutil.copytree(module_dir, backup_dir)

                with zipfile.ZipFile(zip_path, "r") as zf:
                    zf.extractall(str(module_dir))

                zip_path.unlink(missing_ok=True)

                # Atualiza manifest local
                if name in manifest.get("modules", {}):
                    manifest["modules"][name]["version"] = remote_ver

                self.log.emit(f"✅  {display} atualizado para v{remote_ver}")

            except Exception as e:
                self.log.emit(f"❌  Erro ao atualizar {display}: {e}")
                success = False

                # Restaura backup se existir
                backup_dir = Path(MODULES_DIR) / f"{name}_backup"
                module_dir = Path(MODULES_DIR) / name
                if backup_dir.exists():
                    if module_dir.exists():
                        shutil.rmtree(module_dir)
                    shutil.copytree(backup_dir, module_dir)
                    self.log.emit(f"♻️  Backup restaurado para {display}")

        _save_local_manifest(manifest)
        self.progress.emit(100)
        self.finished.emit(success)


class CheckUpdatesWorker(QThread):
    """
    QThread leve que só verifica se há atualizações disponíveis.

    Sinais:
        result(list)    — lista de updates disponíveis
        error(str)      — mensagem de erro, se houver
    """
    result = pyqtSignal(list)
    error = pyqtSignal(str)

    def run(self):
        try:
            updates = check_updates_sync()
            self.result.emit(updates)
        except Exception as e:
            self.error.emit(str(e))
