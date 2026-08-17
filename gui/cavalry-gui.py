#!/usr/bin/env python3
# cavalry-gui.py — PyQt6 front-end for the Cavalry-on-Linux installer.
# Part of CavalryOnLinux-Installer (GPL-3.0).
#
# A friendly GUI for non-technical users: Install / Update / Uninstall buttons,
# live progress output, and a log viewer. Falls back to the CLI scripts under
# the hood (lib/*.sh). If PyQt6 is missing it prints the CLI command instead.

import os
import subprocess
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INSTALL_SH = ROOT / "install.sh"
UNINSTALL_SH = ROOT / "uninstall.sh"


def qt_available() -> bool:
    try:
        import PyQt6.QtCore  # noqa: F401
        import PyQt6.QtWidgets  # noqa: F401
        import PyQt6.QtGui  # noqa: F401
        return True
    except ImportError:
        return False


# Everything PyQt6-related lives inside this function so the module can be
# imported (and fall back to CLI) on machines without PyQt6 installed.
def run_gui() -> int:
    from PyQt6.QtCore import Qt
    from PyQt6.QtGui import QIcon
    from PyQt6.QtWidgets import (
        QApplication, QMainWindow, QPushButton, QPlainTextEdit, QVBoxLayout,
        QHBoxLayout, QLabel, QWidget, QProgressBar,
    )

    class InstallerWindow(QMainWindow):
        def __init__(self) -> None:
            super().__init__()
            self.setWindowTitle("Cavalry on Linux — installer")
            self.resize(720, 520)

            central = QWidget(self)
            layout = QVBoxLayout(central)

            title = QLabel("Cavalry on Linux")
            title.setStyleSheet("font-size: 20px; font-weight: bold;")
            subtitle = QLabel(
                "Installs Cavalry (procedural animation) via Wine. "
                "You will need a free Canva account to sign in."
            )
            subtitle.setWordWrap(True)
            layout.addWidget(title)
            layout.addWidget(subtitle)

            self.log = QPlainTextEdit()
            self.log.setReadOnly(True)
            self.log.setMaximumBlockCount(4000)
            layout.addWidget(self.log, stretch=1)

            self.progress = QProgressBar()
            self.progress.setRange(0, 0)  # indeterminate while running
            self.progress.hide()
            layout.addWidget(self.progress)

            btn_row = QHBoxLayout()
            self.btn_install = QPushButton("Install / Update")
            self.btn_install.clicked.connect(lambda: self.start(["install"]))
            self.btn_uninstall = QPushButton("Uninstall")
            self.btn_uninstall.clicked.connect(lambda: self.start(["uninstall"]))
            self.btn_logs = QPushButton("Open logs folder")
            self.btn_logs.clicked.connect(self.open_logs)
            for b in (self.btn_install, self.btn_uninstall, self.btn_logs):
                btn_row.addWidget(b)
            layout.addLayout(btn_row)

            self.setCentralWidget(central)
            self._running = False
            self.append("Ready. Click “Install / Update” to begin.")

        def append(self, text: str) -> None:
            self.log.appendPlainText(text)

        def open_logs(self) -> None:
            logs = ROOT / ".local" / "logs"
            logs.mkdir(parents=True, exist_ok=True)
            subprocess.Popen(["xdg-open", str(logs)])

        def start(self, args: list[str]) -> None:
            if self._running:
                self.append("Already running an operation — wait for it to finish.")
                return
            self._running = True
            self.btn_install.setEnabled(False)
            self.btn_uninstall.setEnabled(False)
            self.progress.show()
            self.append(f"Starting: {' '.join(args)} ...")

            script = INSTALL_SH if args[0] == "install" else UNINSTALL_SH

            def worker() -> None:
                try:
                    proc = subprocess.Popen(
                        [str(script), *args[1:]],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        text=True,
                        bufsize=1,
                    )
                    assert proc.stdout is not None
                    for line in proc.stdout:
                        self.append(line.rstrip())
                    proc.wait()
                    self.append("✔ Done.")
                except Exception as exc:  # pragma: no cover
                    self.append(f"✗ Failed: {exc}")
                finally:
                    self._running = False
                    self.btn_install.setEnabled(True)
                    self.btn_uninstall.setEnabled(True)
                    self.progress.hide()

            threading.Thread(target=worker, daemon=True).start()

    app = QApplication(sys.argv)
    win = InstallerWindow()
    win.show()
    return app.exec()


def main() -> int:
    if not qt_available():
        print(
            "PyQt6 is not installed — falling back to the terminal installer.\n"
            "Run:  ./install.sh   (see README.md)",
            file=sys.stderr,
        )
        return 1
    return run_gui()


if __name__ == "__main__":
    sys.exit(main())
