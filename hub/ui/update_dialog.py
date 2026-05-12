"""
update_dialog.py — Diálogo de progresso de atualização.
"""
from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel,
    QProgressBar, QTextEdit, QPushButton
)
from PyQt6.QtCore import Qt, pyqtSlot
from PyQt6.QtGui import QTextCursor


class UpdateDialog(QDialog):
    """
    Diálogo modal que exibe o progresso de download e instalação
    de atualizações.
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Atualizando módulos")
        self.setFixedSize(520, 380)
        self.setWindowFlags(
            Qt.WindowType.Dialog |
            Qt.WindowType.WindowTitleHint |
            Qt.WindowType.CustomizeWindowHint
        )
        self._build_ui()
        self._apply_styles()

    # ------------------------------------------------------------------
    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(28, 24, 28, 24)
        layout.setSpacing(16)

        # Título
        title = QLabel("Atualizando módulos…")
        title.setObjectName("DialogTitle")
        layout.addWidget(title)

        # Barra de progresso
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        self.progress_bar.setObjectName("UpdateProgress")
        self.progress_bar.setTextVisible(True)
        self.progress_bar.setFixedHeight(10)
        layout.addWidget(self.progress_bar)

        # Log de texto
        self.log_edit = QTextEdit()
        self.log_edit.setReadOnly(True)
        self.log_edit.setObjectName("LogEdit")
        layout.addWidget(self.log_edit)

        # Botão fechar (desabilitado durante atualização)
        btn_row = QHBoxLayout()
        btn_row.addStretch()
        self.close_btn = QPushButton("Fechar")
        self.close_btn.setObjectName("CloseButton")
        self.close_btn.setFixedSize(110, 36)
        self.close_btn.setEnabled(False)
        self.close_btn.clicked.connect(self.accept)
        btn_row.addWidget(self.close_btn)
        layout.addLayout(btn_row)

    # ------------------------------------------------------------------
    @pyqtSlot(str)
    def append_log(self, message: str):
        self.log_edit.append(message)
        self.log_edit.moveCursor(QTextCursor.MoveOperation.End)

    @pyqtSlot(int)
    def set_progress(self, value: int):
        self.progress_bar.setValue(value)

    @pyqtSlot(bool)
    def on_finished(self, success: bool):
        self.progress_bar.setValue(100)
        if success:
            self.append_log("\n✅ Atualização concluída com sucesso!")
            self.setWindowTitle("Atualização concluída")
        else:
            self.append_log("\n⚠️  Atualização concluída com erros. Verifique o log acima.")
            self.setWindowTitle("Atualização concluída com erros")
        self.close_btn.setEnabled(True)

    # ------------------------------------------------------------------
    def _apply_styles(self):
        self.setStyleSheet("""
            QDialog {
                background: #0f1724;
            }
            QLabel#DialogTitle {
                color: #f0f4ff;
                font-size: 16px;
                font-weight: 700;
                font-family: 'Segoe UI', sans-serif;
            }
            QProgressBar#UpdateProgress {
                background: #1a2035;
                border: none;
                border-radius: 5px;
            }
            QProgressBar#UpdateProgress::chunk {
                background: qlineargradient(
                    x1:0, y1:0, x2:1, y2:0,
                    stop:0 #00d4ff, stop:1 #a855f7
                );
                border-radius: 5px;
            }
            QTextEdit#LogEdit {
                background: #0a0f1e;
                color: #8892a4;
                border: 1px solid rgba(255,255,255,0.07);
                border-radius: 10px;
                font-family: 'Consolas', 'Courier New', monospace;
                font-size: 12px;
                padding: 8px;
            }
            QPushButton#CloseButton {
                background: #1a2035;
                color: #8892a4;
                border: 1px solid rgba(255,255,255,0.1);
                border-radius: 10px;
                font-size: 13px;
                font-family: 'Segoe UI', sans-serif;
            }
            QPushButton#CloseButton:enabled {
                background: qlineargradient(
                    x1:0, y1:0, x2:1, y2:0,
                    stop:0 #00d4ffcc, stop:1 #00d4ff88
                );
                color: #0a0f1e;
                font-weight: 700;
                border: none;
            }
            QPushButton#CloseButton:enabled:hover {
                background: #00d4ff;
            }
        """)
