"""
main_window.py — Janela principal do Hub de Engenharia. Tema EPD-PB amber/dark.
"""
import json
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QScrollArea, QGridLayout,
    QFrame, QMessageBox, QSizePolicy, QSpacerItem
)
from PyQt6.QtCore import Qt, QTimer, pyqtSlot
from PyQt6.QtGui import QFont

from hub.config import TOOLS, HUB_VERSION, MANIFEST_PATH
from hub.core.launcher import open_tool, stop_all
from hub.core.updater import CheckUpdatesWorker, UpdateWorker
from hub.ui.card_widget import ToolCard
from hub.ui.update_dialog import UpdateDialog


class MainWindow(QMainWindow):

    def __init__(self):
        super().__init__()
        self.setWindowTitle(f"Hub de Engenharia  —  EPD-PB  —  v{HUB_VERSION}")
        self.setMinimumSize(860, 560)
        self.resize(980, 660)

        self._cards: dict[str, ToolCard] = {}
        self._pending_updates: list[dict] = []
        self._check_worker: CheckUpdatesWorker | None = None
        self._update_worker: UpdateWorker | None = None

        self._build_ui()
        self._apply_global_styles()
        self._load_local_versions()

        QTimer.singleShot(2000, self._check_updates_background)

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

        # Título
        title = QLabel("HUB DE FERRAMENTAS")
        title.setObjectName("AppTitle")
        layout.addWidget(title)

        # Badge EPD-PB
        badge = QLabel("EPD-PB")
        badge.setObjectName("EpdBadge")
        badge.setFixedSize(56, 20)
        badge.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(badge)

        # Subtítulo
        subtitle = QLabel("Plataforma de ferramentas integradas")
        subtitle.setObjectName("AppSubtitle")
        layout.addWidget(subtitle)

        layout.addStretch()

        # Botão verificar atualizações
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

        # Rótulo da seção
        section = QLabel("FERRAMENTAS DISPONÍVEIS")
        section.setObjectName("SectionTitle")
        outer.addWidget(section)

        outer.addItem(QSpacerItem(0, 14, QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed))

        # Separador
        sep = QFrame()
        sep.setObjectName("Separator")
        sep.setFixedHeight(1)
        outer.addWidget(sep)

        outer.addItem(QSpacerItem(0, 18, QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Fixed))

        # Grid 2 colunas
        self.grid = QGridLayout()
        self.grid.setSpacing(12)

        for idx, (module_name, cfg) in enumerate(TOOLS.items()):
            card = ToolCard(module_name, cfg)
            card.open_requested.connect(self._on_open_tool)
            self._cards[module_name] = card
            row, col = divmod(idx, 2)
            self.grid.addWidget(card, row, col)

        outer.addLayout(self.grid)
        outer.addStretch()

        return scroll

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
    # Versões locais
    # ──────────────────────────────────────────────────────────
    def _load_local_versions(self):
        try:
            with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
                manifest = json.load(f)
            for name, data in manifest.get("modules", {}).items():
                if name in self._cards:
                    self._cards[name].set_version(data.get("version", "?"))
        except (FileNotFoundError, json.JSONDecodeError):
            pass

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

    @pyqtSlot(list)
    def _on_updates_found(self, updates: list):
        self._pending_updates = updates
        self.update_btn.setEnabled(True)
        if not updates:
            self._set_status("✅  Todos os módulos estão atualizados.")
            return
        names = ", ".join(u["display_name"] for u in updates)
        self._set_status(f"  Atualizações disponíveis: {names}")
        for u in updates:
            if u["name"] in self._cards:
                self._cards[u["name"]].set_update_available(True)
        reply = QMessageBox.question(
            self, "Atualizações disponíveis",
            f"{len(updates)} atualização(ões) encontrada(s):\n{names}\n\nDeseja instalar agora?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._run_update(updates)

    @pyqtSlot(str)
    def _on_update_check_error(self, msg: str):
        self.update_btn.setEnabled(True)
        self._set_status(f"Sem conexão com o servidor de atualizações.")

    def _run_update(self, updates: list):
        dialog = UpdateDialog(self)
        self._update_worker = UpdateWorker(updates)
        self._update_worker.log.connect(dialog.append_log)
        self._update_worker.progress.connect(dialog.set_progress)
        self._update_worker.finished.connect(dialog.on_finished)
        self._update_worker.finished.connect(self._on_update_finished)
        self._update_worker.start()
        dialog.exec()

    @pyqtSlot(bool)
    def _on_update_finished(self, success: bool):
        if success:
            self._load_local_versions()
            for card in self._cards.values():
                card.set_update_available(False)
            self._pending_updates = []
            self._set_status("✅  Módulos atualizados com sucesso.")

    # ──────────────────────────────────────────────────────────
    # Abertura de ferramentas
    # ──────────────────────────────────────────────────────────
    @pyqtSlot(str)
    def _on_open_tool(self, module_name: str):
        cfg = TOOLS.get(module_name)
        if not cfg:
            return
        self._set_status(f"Iniciando {cfg['display_name']}…")
        ok, msg = open_tool(module_name, cfg)
        if ok:
            self._set_status(f"✅  {cfg['display_name']} iniciado.")
        else:
            QMessageBox.warning(self, "Módulo não encontrado", msg)
            self._set_status(f"  Falha ao abrir {cfg['display_name']}.")

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
            QPushButton#UpdateButton:hover {
                background: #fbbf24;
            }
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

            QLabel {
                background: transparent;
            }

            QLabel#SectionTitle {
                color: #d1d5db;
                font-size: 10px;
                font-weight: 700;
                letter-spacing: 2px;
            }
            QFrame#Separator {
                background: #1a1f2e;
            }

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
            QMessageBox {
                background: #0d1017;
            }
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
            QMessageBox QPushButton:default:hover {
                background: #fbbf24;
            }
        """)
