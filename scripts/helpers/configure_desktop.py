#!/usr/bin/env python3
"""Run as the target user in a session bus; only seed missing desktop profiles."""
import json
import sys
from config_files import ConfigFiles

PROFILE_ID = '490a35a4-e735-4a44-9ffd-00fb23eb9079'
PALETTE = ['#414868', '#f7768e', '#9ece6a', '#e0af68', '#7aa2f7', '#bb9af7', '#7dcfff', '#a9b1d6',
           '#565f89', '#f7768e', '#9ece6a', '#e0af68', '#7aa2f7', '#bb9af7', '#7dcfff', '#c0caf5']


def backup_settings(files, name, values):
    path = files.backups / name
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(values, ensure_ascii=False, indent=2) + '\n')


def set_value(settings, key, value):
    if not settings.set_value(key, value):
        raise RuntimeError(f'无法保存桌面设置：{key}')


def terminal(files, Gio, GLib):
    profiles = Gio.Settings.new('org.gnome.Terminal.ProfilesList')
    entries = list(profiles.get_strv('list'))
    if PROFILE_ID in entries:
        return  # Includes user edits to the managed profile and default selection.
    profile = Gio.Settings.new_with_path('org.gnome.Terminal.Legacy.Profile',
                                        f'/org/gnome/terminal/legacy/profiles:/:{PROFILE_ID}/')
    values = {'visible-name': ('s', 'Useful Toolds — Midnight'),
              'use-theme-colors': ('b', False), 'background-color': ('s', '#1a1b26'),
              'foreground-color': ('s', '#c0caf5'), 'palette': ('as', PALETTE),
              'use-system-font': ('b', False), 'font': ('s', 'Ubuntu Sans Mono 13'),
              'use-custom-command': ('b', False), 'login-shell': ('b', False)}
    for key in values:
        if not profile.is_writable(key):
            raise RuntimeError(f'终端设置不可写：{key}')
    if not all(profiles.is_writable(key) for key in ('list', 'default')):
        raise RuntimeError('终端配置档设置不可写')
    backup_settings(files, 'terminal.json', {'list': entries, 'default': profiles.get_string('default')})
    for key, (kind, value) in values.items():
        set_value(profile, key, GLib.Variant(kind, value))
    set_value(profiles, 'list', GLib.Variant('as', entries + [PROFILE_ID]))
    set_value(profiles, 'default', GLib.Variant('s', PROFILE_ID))
    files.changed.append('GNOME Terminal 独立 Midnight 配置档（默认进入用户 Shell）')


def chinese(files, Gio, GLib):
    for name in ('profile', 'config', 'conf/pinyin.conf', 'conf/classicui.conf'):
        files.seed(f'fcitx5/{name}', f'.config/fcitx5/{name}')
    settings = Gio.Settings.new('org.gnome.settings-daemon.plugins.xsettings')
    overrides = settings.get_value('overrides').unpack()
    if overrides.get('Gtk/IMModule') != 'fcitx':
        backup_settings(files, 'xsettings-overrides.json', overrides)
        # Preserve value types for unrelated overrides.
        value = settings.get_value('overrides')
        entries = {key: value.lookup_value(key, None) for key in overrides}
        entries['Gtk/IMModule'] = GLib.Variant('s', 'fcitx')
        set_value(settings, 'overrides', GLib.Variant('a{sv}', entries))
        files.changed.append('GNOME 的 Fcitx GTK 输入支持；重新登录后生效')


if __name__ == '__main__':
    from gi.repository import Gio, GLib
    files = ConfigFiles(*sys.argv[1:4])
    {'terminal': terminal, 'chinese': chinese}[sys.argv[4]](files, Gio, GLib)
    Gio.Settings.sync()
    print('、'.join(files.changed), end='')
