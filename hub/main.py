"""
main.py — Entry point do Hub de Engenharia.

Execute com:
    python hub/main.py
"""
import sys
import os

# Garante que a raiz do projeto esteja no sys.path,
# independentemente de como o script é chamado.
_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from PyQt6.QtWidgets import QApplication
from PyQt6.QtGui import QFont
from PyQt6.QtCore import Qt

from hub.ui.main_window import MainWindow


def main():
    # Habilita DPI alto no Windows
    QApplication.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    )

    app = QApplication(sys.argv)
    app.setApplicationName("Hub de Engenharia")
    app.setOrganizationName("EPD-PB")

    # Fonte padrão
    font = QFont("Segoe UI", 10)
    app.setFont(font)

    window = MainWindow()
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
