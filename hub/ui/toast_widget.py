"""
toast_widget.py — Notificações elegantes que desaparecem sozinhas.
"""
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QGraphicsOpacityEffect
)
from PyQt6.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, pyqtSignal

class ToastNotification(QWidget):
    action_clicked = pyqtSignal()

    def __init__(self, parent, message: str, type: str = "info", action_text: str = None, duration_ms: int = 8000):
        super().__init__(parent)
        self.message = message
        self.type = type
        self.action_text = action_text
        self.duration_ms = duration_ms
        
        self.setWindowFlags(Qt.WindowType.SubWindow | Qt.WindowType.FramelessWindowHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        
        self._build_ui()
        self._apply_styles()
        
        self.opacity_effect = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self.opacity_effect)
        self.opacity_effect.setOpacity(0)
        
        self.hide_timer = QTimer(self)
        self.hide_timer.setSingleShot(True)
        self.hide_timer.timeout.connect(self.hide_toast)
        
    def _build_ui(self):
        root = QHBoxLayout(self)
        root.setContentsMargins(12, 12, 12, 12)
        
        self.container = QWidget()
        self.container.setObjectName(f"ToastContainer_{self.type}")
        container_layout = QHBoxLayout(self.container)
        container_layout.setContentsMargins(16, 12, 16, 12)
        container_layout.setSpacing(12)
        
        # Icon
        self.icon_label = QLabel()
        if self.type == "success":
            self.icon_label.setText("✅")
        elif self.type == "error":
            self.icon_label.setText("❌")
        elif self.type == "warning":
            self.icon_label.setText("⚠️")
        else:
            self.icon_label.setText("ℹ️")
        container_layout.addWidget(self.icon_label)
        
        # Message
        self.msg_label = QLabel(self.message)
        self.msg_label.setObjectName("ToastMessage")
        self.msg_label.setWordWrap(True)
        container_layout.addWidget(self.msg_label, stretch=1)
        
        # Action Button
        if self.action_text:
            self.action_btn = QPushButton(self.action_text)
            self.action_btn.setObjectName("ToastActionBtn")
            self.action_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            self.action_btn.clicked.connect(self._on_action_clicked)
            container_layout.addWidget(self.action_btn)
            
        # Close Button
        self.close_btn = QPushButton("✕")
        self.close_btn.setObjectName("ToastCloseBtn")
        self.close_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.close_btn.setFixedSize(24, 24)
        self.close_btn.clicked.connect(self.hide_toast)
        container_layout.addWidget(self.close_btn)
        
        root.addWidget(self.container)
        
    def _apply_styles(self):
        base_color = {
            "success": "#10b981",
            "error": "#ef4444",
            "warning": "#f59e0b",
            "info": "#3b82f6",
            "special": "#a855f7"
        }.get(self.type, "#3b82f6")
        
        self.setStyleSheet(f"""
            QWidget#ToastContainer_{self.type} {{
                background: #1e293b;
                border: 1px solid {base_color};
                border-radius: 8px;
            }}
            QLabel#ToastMessage {{
                color: #f8fafc;
                font-family: 'Segoe UI', sans-serif;
                font-size: 13px;
            }}
            QPushButton#ToastActionBtn {{
                background: {base_color};
                color: #ffffff;
                font-family: 'Segoe UI', sans-serif;
                font-size: 12px;
                font-weight: bold;
                border: none;
                border-radius: 4px;
                padding: 6px 12px;
            }}
            QPushButton#ToastActionBtn:hover {{
                opacity: 0.9;
            }}
            QPushButton#ToastCloseBtn {{
                background: transparent;
                color: #94a3b8;
                border: none;
                font-size: 14px;
            }}
            QPushButton#ToastCloseBtn:hover {{
                color: #f8fafc;
            }}
        """)
        
    def _on_action_clicked(self):
        self.action_clicked.emit()
        self.hide_toast()

    def show_toast(self):
        if not self.parent():
            return
            
        parent_rect = self.parent().rect()
        self.adjustSize()
        
        # Posição: canto superior direito
        x = parent_rect.width() - self.width() - 20
        y = 20
        self.move(x, y)
        
        self.show()
        
        self.anim = QPropertyAnimation(self.opacity_effect, b"opacity")
        self.anim.setDuration(300)
        self.anim.setStartValue(0)
        self.anim.setEndValue(1)
        self.anim.setEasingCurve(QEasingCurve.Type.OutQuad)
        self.anim.start()
        
        if self.duration_ms > 0:
            self.hide_timer.start(self.duration_ms)
            
    def hide_toast(self):
        self.hide_timer.stop()
        self.anim = QPropertyAnimation(self.opacity_effect, b"opacity")
        self.anim.setDuration(300)
        self.anim.setStartValue(1)
        self.anim.setEndValue(0)
        self.anim.setEasingCurve(QEasingCurve.Type.InQuad)
        self.anim.finished.connect(self.close)
        self.anim.start()
