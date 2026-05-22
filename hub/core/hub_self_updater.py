"""
hub_self_updater.py — Realiza o download da nova versão do Hub e faz a substituição.
"""
import os
import sys
import time
import requests
import subprocess
from PyQt6.QtCore import QThread, pyqtSignal

class HubSelfUpdateWorker(QThread):
    progress = pyqtSignal(int)
    log = pyqtSignal(str)
    finished = pyqtSignal(bool)

    def __init__(self, download_url: str):
        super().__init__()
        self.download_url = download_url
        self._is_exe = getattr(sys, 'frozen', False)

    def run(self):
        try:
            if not self._is_exe:
                self.log.emit("⚠️ Modo de desenvolvimento detectado. Auto-update do Hub ignorado.")
                self.finished.emit(True)
                return

            exe_path = sys.executable
            new_exe_path = f"{exe_path}.new"
            bat_path = os.path.join(os.path.dirname(exe_path), "update_hub.bat")

            self.log.emit("Baixando nova versão do Hub...")
            
            # Download
            with requests.get(self.download_url, stream=True, timeout=15) as r:
                r.raise_for_status()
                total_length = r.headers.get('content-length')
                
                with open(new_exe_path, 'wb') as f:
                    if total_length is None:
                        f.write(r.content)
                        self.progress.emit(100)
                    else:
                        dl = 0
                        total_length = int(total_length)
                        for data in r.iter_content(chunk_size=4096):
                            dl += len(data)
                            f.write(data)
                            done = int(100 * dl / total_length)
                            self.progress.emit(done)
                            
            self.log.emit("Download concluído. Preparando substituição...")

            # Cria script .bat para substituir
            bat_content = f"""@echo off
echo Atualizando Hub de Engenharia...
timeout /t 2 /nobreak > nul
del "{exe_path}"
ren "{new_exe_path}" "{os.path.basename(exe_path)}"
start "" "{exe_path}"
del "%~f0"
"""
            with open(bat_path, "w", encoding="utf-8") as f:
                f.write(bat_content)

            self.log.emit("Script criado. O Hub será reiniciado.")
            time.sleep(1)
            
            # Executa script
            subprocess.Popen([bat_path], creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
            
            self.finished.emit(True)
            
        except Exception as e:
            self.log.emit(f"Erro na auto-atualização do Hub:\n{e}")
            self.finished.emit(False)
