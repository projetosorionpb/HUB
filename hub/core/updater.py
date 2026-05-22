"""
updater.py — Verificação e download de atualizações via manifest.json remoto no GitHub.

Fluxo:
  1. Busca manifest.json da branch main do repositório GitHub.
  2. Compara com o manifest.json local.
  3. Emite sinais PyQt para atualizar a UI.
  4. Baixa e extrai .zip dos módulos desatualizados OU novos.
"""
import json
import os
import zipfile
import shutil
from pathlib import Path

import requests
from packaging.version import Version
from PyQt6.QtCore import QThread, pyqtSignal

from hub.config import MANIFEST_RAW_URL, MODULES_DIR, MANIFEST_PATH


def _load_local_manifest() -> dict:
    try:
        with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"modules": {}}


def _save_local_manifest(data: dict) -> None:
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def fetch_remote_manifest() -> dict:
    """Busca o manifest.json da branch main do GitHub."""
    resp = requests.get(MANIFEST_RAW_URL, timeout=10)
    resp.raise_for_status()
    return resp.json()


def check_updates_sync() -> dict:
    """
    Compara manifest local com o remoto e retorna:
      {
        "updates": [{"name", "display_name", "local", "remote", "download_url"}],
        "new":     [{"name", "display_name", "version", "download_url", "cfg"}]
      }
    """
    local = _load_local_manifest()
    result: dict = {"updates": [], "new": [], "metadata_updates": []}

    try:
        remote = fetch_remote_manifest()
    except Exception:
        return result

    local_modules: dict = local.get("modules", {})
    remote_modules: dict = remote.get("modules", {})
    
    # Verifica atualização do próprio Hub
    try:
        from hub.config import HUB_VERSION
        remote_hub_ver = remote.get("hub_version", "1.0.0")
        if Version(remote_hub_ver) > Version(HUB_VERSION):
            hub_download_url = remote.get("hub_download_url")
            if hub_download_url:
                result["hub_update"] = {
                    "version": remote_hub_ver,
                    "download_url": hub_download_url
                }
    except Exception:
        pass

    for name, remote_data in remote_modules.items():
        remote_ver = remote_data.get("version", "0.0.0")
        download_url = remote_data.get("download_url", "")
        module_type = remote_data.get("type", "exe")

        is_web = (module_type == "web")

        if not download_url and not is_web:
            # Módulo sem URL de download e não é web — ignora
            continue

        if name not in local_modules:
            # Módulo novo
            result["new"].append({
                "name": name,
                "display_name": remote_data.get("display_name", name),
                "version": remote_ver,
                "download_url": download_url,
                "cfg": remote_data,
                "auto_register": is_web
            })
        else:
            # Módulo existente: verifica se tem versão mais nova
            local_ver = local_modules[name].get("version", "0.0.0")
            local_entry = local_modules[name].get("entry", "")
            remote_entry = remote_data.get("entry", "")
            
            try:
                if Version(remote_ver) > Version(local_ver) or (is_web and local_entry != remote_entry):
                    result["updates"].append({
                        "name": name,
                        "display_name": remote_data.get("display_name", name),
                        "local": local_ver,
                        "remote": remote_ver,
                        "download_url": download_url,
                        "is_new": False,
                        "cfg": remote_data, # Necessário para o bug fix 5.1 e para web update
                        "auto_register": is_web
                    })
                elif Version(remote_ver) == Version(local_ver):
                    # Compara se houve alguma alteração de metadados relevantes
                    metadata_keys = ["display_name", "description", "type", "exe_name", "port", "entry", "color", "icon_svg", "download_url"]
                    changed = False
                    for key in metadata_keys:
                        if local_modules[name].get(key) != remote_data.get(key):
                            changed = True
                            break
                    if changed:
                        result["metadata_updates"].append({
                            "name": name,
                            "cfg": remote_data
                        })
            except Exception:
                pass

    return result


class UpdateWorker(QThread):
    """
    QThread que executa download e instalação de módulos em background.
    Suporta tanto atualizações quanto instalações novas (is_new=True).

    Sinais:
        log(str)        — mensagem de progresso
        progress(int)   — percentual 0-100
        finished(bool)  — True = sucesso, False = erro
    """
    log = pyqtSignal(str)
    progress = pyqtSignal(int)
    finished = pyqtSignal(bool)

    def __init__(self, items: list[dict], parent=None):
        """
        items: lista de dicts com chaves:
          name, display_name, download_url, remote (versão), is_new (bool, opcional)
          Para módulos novos: também precisa de 'cfg' (dict completo do manifest remoto)
        """
        super().__init__(parent)
        self.items = items

    def run(self):
        total = len(self.items)
        if total == 0:
            self.log.emit("Nenhuma atualização para instalar.")
            self.finished.emit(True)
            return

        manifest = _load_local_manifest()
        success = True

        for idx, item in enumerate(self.items):
            name = item["name"]
            display = item["display_name"]
            url = item["download_url"]
            remote_ver = item.get("remote") or item.get("version", "?")
            is_new = item.get("is_new", False)

            action = "Instalando" if is_new else "Atualizando"
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

                self.log.emit(f"📦  {action} {display}...")

                module_dir = Path(MODULES_DIR) / name
                backup_dir = Path(MODULES_DIR) / f"{name}_backup"

                # Backup do módulo atual (só para updates)
                if not is_new and module_dir.exists():
                    if backup_dir.exists():
                        shutil.rmtree(backup_dir)
                    shutil.copytree(module_dir, backup_dir)

                module_dir.mkdir(parents=True, exist_ok=True)
                with zipfile.ZipFile(zip_path, "r") as zf:
                    zf.extractall(str(module_dir))

                zip_path.unlink(missing_ok=True)

                # Atualiza/cria entrada no manifest local
                if is_new:
                    cfg = item.get("cfg", {})
                    manifest.setdefault("modules", {})[name] = {
                        **cfg,
                        "version": remote_ver,
                    }
                    self.log.emit(f"✅  {display} v{remote_ver} instalado!")
                else:
                    if name in manifest.get("modules", {}):
                        cfg = item.get("cfg", {})
                        manifest["modules"][name].update(cfg)
                        manifest["modules"][name]["version"] = remote_ver
                    self.log.emit(f"✅  {display} atualizado para v{remote_ver}")

            except Exception as e:
                self.log.emit(f"❌  Erro ao processar {display}: {e}")
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
    QThread leve que verifica atualizações e novos módulos disponíveis.

    Sinais:
        result(dict)  — {"updates": [...], "new": [...]}
        error(str)    — mensagem de erro, se houver
    """
    result = pyqtSignal(dict)
    error = pyqtSignal(str)

    def run(self):
        try:
            data = check_updates_sync()
            self.result.emit(data)
        except Exception as e:
            self.error.emit(str(e))
