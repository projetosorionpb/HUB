"""
main_window.py — Janela principal do Hub de Engenharia. Tema EPD-PB amber/dark.

As ferramentas são carregadas dinamicamente do manifest.json local.
Módulos novos (disponíveis no servidor mas não instalados) aparecem como
cards "fantasma" com botão INSTALAR.
"""
import json
import os
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QScrollArea, QGridLayout,
    QFrame, QMessageBox, QSizePolicy, QSpacerItem
)
from PyQt6.QtCore import Qt, QTimer, pyqtSlot
from PyQt6.QtGui import QFont

from hub.config import HUB_VERSION, MANIFEST_PATH
from hub.core.launcher import open_tool, stop_all
from hub.core.updater import CheckUpdatesWorker, UpdateWorker
from hub.core.hub_self_updater import HubSelfUpdateWorker
from hub.ui.card_widget import ToolCard
from hub.ui.update_dialog import UpdateDialog
from hub.ui.toast_widget import ToastNotification


class MainWindow(QMainWindow):

    def __init__(self):
        super().__init__()
        self.setWindowTitle(f"Hub de Engenharia  —  EPD-PB  —  v{HUB_VERSION}")
        self.setMinimumSize(860, 560)
        self.resize(980, 660)

        self._cards: dict[str, ToolCard] = {}
        self._card_count: int = 0
        self._pending_updates: list[dict] = []
        self._pending_new: list[dict] = []
        self._check_worker: CheckUpdatesWorker | None = None
        self._update_worker: UpdateWorker | None = None

        self._build_ui()
        self._apply_global_styles()

        # Auto-bootstrapping do manifest.json local
        delay = 2000
        if not os.path.exists(MANIFEST_PATH):
            try:
                with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
                    json.dump({"hub_version": HUB_VERSION, "modules": {}}, f, indent=2)
                delay = 500  # Acelera a primeira verificação se é instalação nova
            except Exception:
                pass

        QTimer.singleShot(delay, self._check_updates_background)

    # ──────────────────────────────────────────────────────────
    # Construção da UI
    # ──────────────────────────────────────────────────────────
    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)

        root = QVBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        root.addWidget(self._build_header())
        root.addWidget(self._build_body(), stretch=1)
        root.addWidget(self._build_statusbar())

    # ── Header ────────────────────────────────────────────────
    def _build_header(self) -> QWidget:
        header = QFrame()
        header.setObjectName("Header")
        header.setFixedHeight(56)

        layout = QHBoxLayout(header)
        layout.setContentsMargins(28, 0, 28, 0)
        layout.setSpacing(12)

        title = QLabel("HUB DE FERRAMENTAS")
        title.setObjectName("AppTitle")
        layout.addWidget(title)

        badge = QLabel("EPD-PB")
        badge.setObjectName("EpdBadge")
        badge.setFixedSize(56, 20)
        badge.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(badge)

        subtitle = QLabel("Plataforma de ferramentas integradas")
        subtitle.setObjectName("AppSubtitle")
        layout.addWidget(subtitle)

        layout.addStretch()

        self.update_btn = QPushButton("↻  Verificar Atualizações")
        self.update_btn.setObjectName("UpdateButton")
        self.update_btn.setFixedSize(200, 32)
        self.update_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.update_btn.clicked.connect(self._on_check_updates_clicked)
        layout.addWidget(self.update_btn)

        return header

    # ── Body ──────────────────────────────────────────────────
    def _build_body(self) -> QWidget:
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setObjectName("BodyScroll")
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setFrameShape(QFrame.Shape.NoFrame)

        container = QWidget()
        container.setObjectName("BodyContainer")
        scroll.setWidget(container)

        outer = QVBoxLayout(container)
        outer.setContentsMargins(28, 24, 28, 28)
        outer.setSpacing(0)

        section = QLabel("FERRAMENTAS DISPONÍVEIS")
        section.setObjectName("SectionTitle")
        outer.addWidget(section)

        outer.addItem(QSpacerItem(0, 14, QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed))

        sep = QFrame()
        sep.setObjectName("Separator")
        sep.setFixedHeight(1)
        outer.addWidget(sep)

        outer.addItem(QSpacerItem(0, 18, QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed))

        # Grid 2 colunas — preenchido com módulos do manifest local
        self.grid = QGridLayout()
        self.grid.setSpacing(12)
        outer.addLayout(self.grid)

        self._load_cards_from_manifest()

        outer.addStretch()
        return scroll

    def _load_cards_from_manifest(self):
        """Lê o manifest.json local e cria um card para cada módulo."""
        try:
            with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                manifest = json.load(f)
            tools = manifest.get("modules", {})
        except (FileNotFoundError, json.JSONDecodeError):
            tools = {}

        for module_name, cfg in tools.items():
            self._add_card(module_name, cfg, installed=True)

    def _add_card(self, module_name: str, cfg: dict, installed: bool = True) -> ToolCard:
        """Cria e adiciona um card ao grid. Retorna o card criado."""
        card = ToolCard(module_name, cfg)
        card.open_requested.connect(self._on_open_tool)
        card.install_requested.connect(self._on_install_tool)
        if not installed:
            card.set_not_installed(True)

        self._cards[module_name] = card
        row, col = divmod(self._card_count, 2)
        self.grid.addWidget(card, row, col)
        self._card_count += 1
        return card

    # ── Status bar ────────────────────────────────────────────
    def _build_statusbar(self) -> QWidget:
        bar = QFrame()
        bar.setObjectName("StatusBar")
        bar.setFixedHeight(32)

        layout = QHBoxLayout(bar)
        layout.setContentsMargins(28, 0, 28, 0)

        self.status_label = QLabel("Pronto.")
        self.status_label.setObjectName("StatusLabel")
        layout.addWidget(self.status_label)
        layout.addStretch()

        right = QLabel(f"v{HUB_VERSION}  ·  Desenvolvido por Valdeci Nunes — EPD-PB")
        right.setObjectName("StatusRight")
        layout.addWidget(right)

        return bar

    # ──────────────────────────────────────────────────────────
    # Atualizações
    # ──────────────────────────────────────────────────────────
    def _check_updates_background(self):
        self._set_status("Verificando atualizações…")
        self.update_btn.setEnabled(False)
        self._check_worker = CheckUpdatesWorker()
        self._check_worker.result.connect(self._on_updates_found)
        self._check_worker.error.connect(self._on_update_check_error)
        self._check_worker.start()

    @pyqtSlot()
    def _on_check_updates_clicked(self):
        self._check_updates_background()

    @pyqtSlot(dict)
    def _on_updates_found(self, result: dict):
        updates: list[dict] = result.get("updates", [])
        new_modules: list[dict] = result.get("new", [])

        self._pending_updates = updates
        self._pending_new = new_modules
        self.update_btn.setEnabled(True)

        # Processa os módulos web (auto_register) imediatamente
        auto_registered = False
        if new_modules or updates:
            try:
                with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                    manifest = json.load(f)
            except Exception:
                manifest = {"hub_version": HUB_VERSION, "modules": {}}
                
            for lst in (new_modules, updates):
                # Iterar com cópia [:] pois removeremos itens
                for item in lst[:]:
                    if item.get("auto_register"):
                        name = item["name"]
                        cfg = item["cfg"]
                        
                        # Atualiza manifest
                        manifest.setdefault("modules", {})[name] = {
                            **cfg,
                            "version": item.get("remote", item.get("version", "0.0.0"))
                        }
                        auto_registered = True
                        
                        # Adiciona ou atualiza card
                        if name not in self._cards:
                            self._add_card(name, cfg, installed=True)
                        else:
                            self._cards[name].cfg = cfg
                            self._cards[name].set_update_available(False)
                            self._cards[name].set_not_installed(False)
                            
                        # Remove da lista para não passar pro UpdateWorker
                        lst.remove(item)
                        
            if auto_registered:
                with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
                    json.dump(manifest, f, indent=2, ensure_ascii=False)

        # Processa hub_update primeiro
        hub_update = result.get("hub_update")
        if hub_update:
            ver = hub_update["version"]
            url = hub_update["download_url"]
            self._hub_download_url = url
            
            toast = ToastNotification(
                self, 
                f"Nova versão do Hub disponível (v{ver})",
                type="special",
                action_text="Atualizar Hub",
                duration_ms=0 # Não some sozinho
            )
            toast.action_clicked.connect(self._run_hub_update)
            toast.show_toast()
            return
            
        if not updates and not new_modules:
            self._set_status("✅  Todos os módulos estão atualizados.")
            ToastNotification(self, "Todos os módulos estão atualizados.", type="success").show_toast()
            return

        # Marca cards existentes com atualização
        for u in updates:
            if u["name"] in self._cards:
                self._cards[u["name"]].set_update_available(True)

        # Adiciona cards para módulos novos (não instalados)
        for m in new_modules:
            if m["name"] not in self._cards:
                self._add_card(m["name"], m["cfg"], installed=False)

        # Monta mensagem de status
        parts = []
        if updates:
            parts.append(f"{len(updates)} atualização(ões)")
        if new_modules:
            parts.append(f"{len(new_modules)} programa(s) novo(s)")
        
        msg = f"{' e '.join(parts)} disponível(is)."
        self._set_status(f"  {msg}")

        # Se há atualizações de versão, mostra toast ao invés de popup
        if updates:
            toast = ToastNotification(
                self,
                msg,
                type="warning",
                action_text="Instalar agora",
                duration_ms=10000
            )
            toast.action_clicked.connect(lambda: self._run_update(updates))
            toast.show_toast()
    @pyqtSlot(str)
    def _on_update_check_error(self, msg: str):
        self.update_btn.setEnabled(True)
        self._set_status("Sem conexão com o servidor de atualizações.")
        ToastNotification(self, "Sem conexão com o servidor.", type="info", duration_ms=4000).show_toast()

    def _run_update(self, items: list[dict]):
        dialog = UpdateDialog(self)
        self._update_worker = UpdateWorker(items)
        self._update_worker.log.connect(dialog.append_log)
        self._update_worker.progress.connect(dialog.set_progress)
        self._update_worker.finished.connect(dialog.on_finished)
        self._update_worker.finished.connect(self._on_update_finished)
        self._update_worker.start()
        dialog.exec()

    def _run_hub_update(self):
        if not hasattr(self, "_hub_download_url"):
            return
            
        dialog = UpdateDialog(self)
        dialog.setWindowTitle("Atualizando o Hub")
        
        self._hub_worker = HubSelfUpdateWorker(self._hub_download_url)
        self._hub_worker.log.connect(dialog.append_log)
        self._hub_worker.progress.connect(dialog.set_progress)
        self._hub_worker.finished.connect(dialog.on_finished)
        
        self._hub_worker.start()
        dialog.exec()

    @pyqtSlot(bool)
    def _on_update_finished(self, success: bool):
        if success:
            # Relê manifest local para saber o que foi instalado
            try:
                with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                    manifest = json.load(f)
                installed_names = set(manifest.get("modules", {}).keys())
            except Exception:
                installed_names = set()

            for name, card in self._cards.items():
                card.set_update_available(False)
                if name in installed_names:
                    card.set_not_installed(False)

            self._pending_updates = []
            self._pending_new = []
            self._set_status("✅  Módulos atualizados com sucesso.")
            ToastNotification(self, "Módulos atualizados com sucesso!", type="success").show_toast()

    # ──────────────────────────────────────────────────────────
    # Abertura e instalação de ferramentas
    # ──────────────────────────────────────────────────────────
    @pyqtSlot(str)
    def _on_open_tool(self, module_name: str):
        card = self._cards.get(module_name)
        if not card:
            return
        cfg = card.cfg
        self._set_status(f"Iniciando {cfg.get('display_name', module_name)}…")
        ok, msg = open_tool(module_name, cfg)
        if ok:
            self._set_status(f"✅  {cfg.get('display_name', module_name)} iniciado.")
        else:
            ToastNotification(self, f"Módulo não encontrado:\n{msg}", type="error", duration_ms=5000).show_toast()
            self._set_status(f"  Falha ao abrir {cfg.get('display_name', module_name)}.")

    @pyqtSlot(str)
    def _on_install_tool(self, module_name: str):
        """Inicia o download e instalação de um módulo novo."""
        pending = next(
            (m for m in self._pending_new if m["name"] == module_name), None
        )
        if not pending:
            ToastNotification(
                self, 
                "Não foi possível encontrar os dados de instalação.\nClique em 'Verificar Atualizações' e tente novamente.", 
                type="error", 
                duration_ms=6000
            ).show_toast()
            return

        item = {
            "name": module_name,
            "display_name": pending["display_name"],
            "remote": pending["version"],
            "download_url": pending["download_url"],
            "cfg": pending["cfg"],
            "is_new": True,
        }
        self._run_update([item])

    def _set_status(self, msg: str):
        self.status_label.setText(msg)

    def closeEvent(self, event):
        stop_all()
        event.accept()

    # ──────────────────────────────────────────────────────────
    # Estilos globais — tema EPD-PB amber/dark
    # ──────────────────────────────────────────────────────────
    def _apply_global_styles(self):
        self.setStyleSheet("""
            /* ── Base ────────────────────────────────────────── */
            QMainWindow, QWidget {
                background: #0a0c10;
                font-family: 'Segoe UI', sans-serif;
            }

            /* ── Header ─────────────────────────────────────── */
            QFrame#Header {
                background: #0a0c10;
                border-bottom: 1px solid #1a1f2e;
            }
            QLabel#AppTitle {
                color: #f59e0b;
                font-size: 15px;
                font-weight: 700;
                letter-spacing: 2px;
            }
            QLabel#EpdBadge {
                background: #f59e0b;
                color: #0a0c10;
                font-size: 9px;
                font-weight: 800;
                letter-spacing: 1px;
                border-radius: 3px;
            }
            QLabel#AppSubtitle {
                color: #d1d5db;
                font-size: 11px;
                margin-left: 4px;
            }
            QPushButton#UpdateButton {
                background: #f59e0b;
                color: #0a0c10;
                border: none;
                border-radius: 5px;
                font-size: 11px;
                font-weight: 700;
                letter-spacing: 1px;
            }
            QPushButton#UpdateButton:hover   { background: #fbbf24; }
            QPushButton#UpdateButton:disabled {
                background: #1a1f2e;
                color: #2e3548;
            }

            /* ── Body ───────────────────────────────────────── */
            QWidget#BodyContainer { background: #0a0c10; }
            QScrollArea#BodyScroll { background: #0a0c10; border: none; }

            QScrollBar:vertical {
                background: #0a0c10;
                width: 6px;
            }
            QScrollBar::handle:vertical {
                background: #1a1f2e;
                border-radius: 3px;
            }
            QScrollBar::add-line:vertical,
            QScrollBar::sub-line:vertical { height: 0; }

            QLabel { background: transparent; }

            QLabel#SectionTitle {
                color: #d1d5db;
                font-size: 10px;
                font-weight: 700;
                letter-spacing: 2px;
            }
            QFrame#Separator { background: #1a1f2e; }

            /* ── Status bar ─────────────────────────────────── */
            QFrame#StatusBar {
                background: #0a0c10;
                border-top: 1px solid #1a1f2e;
            }
            QLabel#StatusLabel {
                color: #d1d5db;
                font-size: 11px;
            }
            QLabel#StatusRight {
                color: #1a1f2e;
                font-size: 10px;
            }

            /* ── QMessageBox ────────────────────────────────── */
            QMessageBox { background: #0d1017; }
            QMessageBox QLabel {
                color: #c0c8d8;
                font-size: 12px;
            }
            QMessageBox QPushButton {
                background: #13161e;
                color: #8892a4;
                border: 1px solid #1a1f2e;
                border-radius: 5px;
                padding: 5px 18px;
                min-width: 70px;
                font-size: 12px;
            }
            QMessageBox QPushButton:default {
                background: #f59e0b;
                color: #0a0c10;
                border: none;
                font-weight: 700;
            }
            QMessageBox QPushButton:default:hover { background: #fbbf24; }
        """)
