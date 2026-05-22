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
    request_close = pyqtSignal()  # Sinal para fechar o app antes de executar o bat

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
            exe_dir = os.path.dirname(exe_path)
            exe_name = os.path.basename(exe_path)
            new_exe_path = os.path.join(exe_dir, f"{exe_name}.new")
            bat_path = os.path.join(exe_dir, "update_hub.bat")

            self.log.emit("Baixando nova versão do Hub...")
            
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            }
            
            is_zip = self.download_url.lower().endswith(".zip")
            download_dest = os.path.join(exe_dir, f"{exe_name}.zip") if is_zip else new_exe_path

            # Download
            with requests.get(self.download_url, headers=headers, stream=True, timeout=60) as r:
                r.raise_for_status()
                total_length = r.headers.get('content-length')
                
                with open(download_dest, 'wb') as f:
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
                            
            if is_zip:
                self.log.emit("Extraindo executável do arquivo compactado...")
                import zipfile
                with zipfile.ZipFile(download_dest, "r") as zf:
                    exe_in_zip = None
                    for name in zf.namelist():
                        if name.lower().endswith(".exe"):
                            exe_in_zip = name
                            break
                    if not exe_in_zip:
                        raise Exception("Nenhum arquivo executável (.exe) encontrado dentro do ZIP de atualização.")
                    
                    with open(new_exe_path, "wb") as f_out:
                        f_out.write(zf.read(exe_in_zip))
                
                try:
                    os.remove(download_dest)
                except Exception:
                    pass
                            
            self.log.emit("Download concluído. Preparando substituição...")

            # Usa o PID do processo atual para o taskkill
            pid = os.getpid()

            # Cria script .bat para substituir
            # O bat mata o processo pelo PID, espera, substitui e reinicia
            bat_content = f"""@echo off
echo Atualizando Hub de Engenharia...
echo Encerrando processo (PID {pid})...
taskkill /F /PID {pid} >nul 2>&1
timeout /t 3 /nobreak >nul
echo Substituindo executavel...
:retry
del "{exe_path}" >nul 2>&1
if exist "{exe_path}" (
    echo Aguardando liberacao do arquivo...
    timeout /t 2 /nobreak >nul
    goto retry
)
ren "{new_exe_path}" "{exe_name}"
echo Iniciando nova versao...
start "" "{exe_path}"
del "%~f0"
"""
            with open(bat_path, "w", encoding="utf-8") as f:
                f.write(bat_content)

            self.log.emit("Hub será reiniciado em instantes...")
            self.progress.emit(100)
            
            # Executa script bat (ele vai matar este processo)
            subprocess.Popen(
                [bat_path],
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
                cwd=exe_dir
            )
            
            # Dá tempo para o bat iniciar antes de sinalizar
            time.sleep(1)
            
            self.finished.emit(True)
            
        except Exception as e:
            self.log.emit(f"Erro na auto-atualização do Hub:\n{e}")
            self.finished.emit(False)

