"""Small user-owned config helpers; no changes happen on import."""
from pathlib import Path
import shutil


class ConfigFiles:
    def __init__(self, home, templates, run_id):
        self.home = Path(home)
        self.templates = Path(templates)
        self.backups = self.home / '.local/state/useful-toolds/backups' / run_id
        self.changed = []

    def backup(self, path):
        path = Path(path)
        if path.exists():
            target = self.backups / path.relative_to(self.home)
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)

    def write(self, path, text):
        path = Path(path)
        if path.is_symlink() and not path.exists():
            raise ValueError(f'{path} 是失效链接，请先检查')
        if path.exists():
            if not path.is_file():
                raise ValueError(f'{path} 不是普通文件')
            if path.read_text() == text:
                return
            self.backup(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        self.changed.append(str(path.relative_to(self.home)))

    def seed(self, template, destination):
        path = self.home / destination
        if path.exists() or path.is_symlink():
            if not path.is_file():
                raise ValueError(f'{path} 已存在但不是可用文件，请检查')
            return
        self.write(path, (self.templates / template).read_text())
