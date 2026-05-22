"""
card_widget.py — Card de ferramenta, estilo EPD-PB amber/dark.
Suporta três estados: normal (ABRIR), atualização disponível (ATUALIZAR),
e não instalado (INSTALAR — módulo novo disponível no servidor).
"""
from PyQt6.QtWidgets import (
    QFrame, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QSizePolicy
)
from PyQt6.QtCore import Qt, pyqtSignal


class ToolCard(QFrame):
    """Card visual que representa uma ferramenta no hub."""
    open_requested = pyqtSignal(str)
    install_requested = pyqtSignal(str)

    def __init__(self, module_name: str, cfg: dict, parent=None):
        super().__init__(parent)
        self.module_name = module_name
        self.cfg = cfg
        self._not_installed = False
        self._build_ui()
        self._apply_styles()

    def _build_ui(self):
        self.setObjectName("ToolCard")
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        self.setFixedHeight(160)

        root = QVBoxLayout(self)
        root.setContentsMargins(22, 18, 22, 18)
        root.setSpacing(8)

        # ── Linha superior: nome ──────────────────
        top = QHBoxLayout()
        top.setSpacing(10)

        self.name_label = QLabel(self.cfg.get("display_name", self.module_name).upper())
        self.name_label.setObjectName("CardTitle")
        top.addWidget(self.name_label)
        top.addStretch()

        root.addLayout(top)

        # ── Badge de status ──────────────────────
        self.badge_label = QLabel()
        self.badge_label.setObjectName("UpdateBadge")
        self.badge_label.setVisible(False)
        root.addWidget(self.badge_label)

        # ── Descrição ────────────────────────────
        self.desc_label = QLabel(self.cfg.get("description", ""))
        self.desc_label.setObjectName("CardDesc")
        self.desc_label.setWordWrap(True)
        root.addWidget(self.desc_label)

        root.addStretch()

        # ── Linha inferior: botão ─────────────────
        bottom = QHBoxLayout()
        bottom.addStretch()

        self.open_btn = QPushButton("ABRIR")
        self.open_btn.setObjectName("OpenButton")
        self.open_btn.setFixedSize(110, 32)
        self.open_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.open_btn.clicked.connect(self._on_btn_clicked)
        bottom.addWidget(self.open_btn)

        root.addLayout(bottom)

    def _on_btn_clicked(self):
        if self._not_installed:
            self.install_requested.emit(self.module_name)
        else:
            self.open_requested.emit(self.module_name)

    # ── API pública ────────────────────────────────────────────
    def set_version(self, version: str):
        pass  # versão removida da UI visual

    def set_update_available(self, available: bool):
        if self._not_installed:
            return  # prioridade ao estado "não instalado"
        if available:
            self.badge_label.setText("● Atualização disponível")
            self.badge_label.setVisible(True)
            self.open_btn.setText("ATUALIZAR")
        else:
            self.badge_label.setVisible(False)
            self.open_btn.setText("ABRIR")

    def set_not_installed(self, value: bool):
        """Define o card como 'disponível para instalar' (módulo novo no servidor)."""
        self._not_installed = value
        if value:
            self.badge_label.setText("⬇  Disponível para instalar")
            self.badge_label.setObjectName("NewBadge")
            self.badge_label.setVisible(True)
            self.open_btn.setText("INSTALAR")
            self.open_btn.setObjectName("InstallButton")
            self.setObjectName("ToolCardNew")
        else:
            self.badge_label.setObjectName("UpdateBadge")
            self.badge_label.setVisible(False)
            self.open_btn.setText("ABRIR")
            self.open_btn.setObjectName("OpenButton")
            self.setObjectName("ToolCard")
        # Força re-aplicação dos estilos
        self._apply_styles()

    # ── Estilos ────────────────────────────────────────────────
    def _apply_styles(self):
        self.setStyleSheet("""
            QFrame#ToolCard {
                background: #0a0c10;
                border: 1px solid #1a1f2e;
                border-radius: 8px;
            }
            QFrame#ToolCard:hover {
                border: 1px solid #f59e0b;
                background: #0d1017;
            }
            QFrame#ToolCardNew {
                background: #0a0c10;
                border: 1px dashed #2a3048;
                border-radius: 8px;
            }
            QFrame#ToolCardNew:hover {
                border: 1px dashed #4a5568;
                background: #0d1017;
            }

            QLabel {
                background: transparent;
            }

            QLabel#CardTitle {
                color: #f59e0b;
                font-size: 13px;
                font-weight: 700;
                font-family: 'Segoe UI', sans-serif;
                letter-spacing: 1px;
            }
            QFrame#ToolCardNew QLabel#CardTitle {
                color: #6b7280;
            }
            QLabel#CardDesc {
                color: #d1d5db;
                font-size: 12px;
                font-family: 'Segoe UI', sans-serif;
            }
            QFrame#ToolCardNew QLabel#CardDesc {
                color: #4b5563;
            }
            QLabel#UpdateBadge {
                color: #fbbf24;
                font-size: 11px;
                font-family: 'Segoe UI', sans-serif;
            }
            QLabel#NewBadge {
                color: #60a5fa;
                font-size: 11px;
                font-family: 'Segoe UI', sans-serif;
            }

            QPushButton#OpenButton {
                background: #f59e0b;
                color: #0a0c10;
                font-size: 11px;
                font-weight: 700;
                font-family: 'Segoe UI', sans-serif;
                letter-spacing: 1px;
                border: none;
                border-radius: 5px;
            }
            QPushButton#OpenButton:hover  { background: #fbbf24; }
            QPushButton#OpenButton:pressed { background: #d97706; }

            QPushButton#InstallButton {
                background: transparent;
                color: #60a5fa;
                font-size: 11px;
                font-weight: 700;
                font-family: 'Segoe UI', sans-serif;
                letter-spacing: 1px;
                border: 1px solid #60a5fa;
                border-radius: 5px;
            }
            QPushButton#InstallButton:hover {
                background: #1e3a5f;
                color: #93c5fd;
                border-color: #93c5fd;
            }
            QPushButton#InstallButton:pressed {
                background: #1e40af;
            }
        """)
