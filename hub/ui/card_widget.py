"""
card_widget.py — Card de ferramenta sem ícone, estilo EPD-PB amber/dark.
"""
from PyQt6.QtWidgets import (
    QFrame, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QSizePolicy
)
from PyQt6.QtCore import Qt, pyqtSignal


class ToolCard(QFrame):
    """Card visual que representa uma ferramenta no hub."""
    open_requested = pyqtSignal(str)

    def __init__(self, module_name: str, cfg: dict, parent=None):
        super().__init__(parent)
        self.module_name = module_name
        self.cfg = cfg
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

        self.name_label = QLabel(self.cfg["display_name"].upper())
        self.name_label.setObjectName("CardTitle")
        top.addWidget(self.name_label)
        top.addStretch()

        root.addLayout(top)

        # ── Badge de atualização ────────────────────────────────
        self.badge_label = QLabel("● Atualização disponível")
        self.badge_label.setObjectName("UpdateBadge")
        self.badge_label.setVisible(False)
        root.addWidget(self.badge_label)

        # ── Descrição ──────────────────────────────────────────
        self.desc_label = QLabel(self.cfg["description"])
        self.desc_label.setObjectName("CardDesc")
        self.desc_label.setWordWrap(True)
        root.addWidget(self.desc_label)

        root.addStretch()

        # ── Linha inferior: botão ─────────────────────
        bottom = QHBoxLayout()
        bottom.addStretch()

        self.open_btn = QPushButton("ABRIR")
        self.open_btn.setObjectName("OpenButton")
        self.open_btn.setFixedSize(100, 32)
        self.open_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.open_btn.clicked.connect(lambda: self.open_requested.emit(self.module_name))
        bottom.addWidget(self.open_btn)

        root.addLayout(bottom)

    # ── API pública ────────────────────────────────────────────
    def set_version(self, version: str):
        # Versão removida da UI conforme solicitado
        pass

    def set_update_available(self, available: bool):
        self.badge_label.setVisible(available)
        self.open_btn.setText("ATUALIZAR" if available else "ABRIR")

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
            QLabel#CardDesc {
                color: #d1d5db;
                font-size: 12px;
                font-family: 'Segoe UI', sans-serif;
            }
            QLabel#UpdateBadge {
                color: #fbbf24;
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
            QPushButton#OpenButton:hover {
                background: #fbbf24;
            }
            QPushButton#OpenButton:pressed {
                background: #d97706;
            }
        """)
