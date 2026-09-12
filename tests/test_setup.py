"""Isolated installer tests: temporary files and mocked system commands only.
Run: python3 -m unittest discover -s tests -v
"""
import importlib.util
import json
import os
from pathlib import Path
import pty
import shlex
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPERS = ROOT / 'scripts/helpers'
sys.path.insert(0, str(HELPERS))
from configure_shell import configure
from docker_config import merge


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)

    def bash(self, body, *, source='scripts/setup_linux.sh'):
        # Real privileged/network commands are never allowed in this harness.
        prelude = f'''
source {shlex.quote(str(ROOT / source))}
TARGET_USER=tester
USER_HOME="$TEST_ROOT/user"
USER_GROUP=tester
RUN_DIR="$TEST_ROOT/run"
RUN_ID=test
CACHE_DIR="$TEST_ROOT/cache"
BACKUP_DIR="$TEST_ROOT/backups"
LOG_FILE="$TEST_ROOT/log"
EVENT_FILE="$TEST_ROOT/events"
CURRENT_MODULE=test
mkdir -p "$USER_HOME" "$RUN_DIR" "$CACHE_DIR" "$BACKUP_DIR"
touch "$EVENT_FILE" "$TEST_ROOT/installed" "$TEST_ROOT/calls"
for command_name in sudo apt-get curl wget chsh usermod groupadd systemctl ubuntu-drivers add-apt-repository docker dockerd; do
    eval "$command_name() {{ printf 'UNEXPECTED: %s\\n' '$command_name' >&2; return 97; }}"
done
'''
        return subprocess.run(['bash', '-c', prelude + body], env={**os.environ, 'TEST_ROOT': str(self.work)},
                              text=True, capture_output=True, timeout=30)

    def check_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_preview_selection_and_invalid_arguments(self):
        for args, expected in [(['--dry-run'], 0),
                               (['--only', 'terminal,terminal', '--dry-run'], 0),
                               (['--only', 'terminal', '--skip', 'shell', '--dry-run'], 1),
                               (['--only', 'cuda', '--dry-run'], 1),
                               (['--only', 'python,', '--dry-run'], 1),
                               (['--only'], 1)]:
            with self.subTest(args=args):
                # A dry run must return before even attempting sudo or networking.
                result = self.bash('main ' + shlex.join(args))
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                self.assertNotIn('UNEXPECTED', result.stderr)
                self.assertEqual((self.work / 'events').read_text(), '')
        result = self.bash('main --only terminal --dry-run')
        self.check_ok(result)
        self.assertIn('shell', result.stdout)
        self.assertNotIn('机器人基础', result.stdout)

    def test_interactive_menu(self):
        for inputs, selected in [
            (b'n\n3\np\n\n', 'shell terminal'),
            (b'2 3\n\n', 'base chinese chrome code chatgpt wechat tools python docker nvidia robotics'),
        ]:
            with self.subTest(inputs=inputs):
                master, slave = pty.openpty()
                try:
                    command = f'source {shlex.quote(str(ROOT / "scripts/setup_linux.sh"))}; selection_menu; resolve_modules; printf "SELECTED:%s\\n" "${{MODULES[*]}}"'
                    process = subprocess.Popen(['bash', '-c', command], stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                    os.close(slave)
                    slave = None
                    os.write(master, inputs)
                    output = process.communicate(timeout=10)[0].decode()
                    self.assertEqual(process.returncode, 0, output)
                    self.assertIn('SELECTED:' + selected, output)
                finally:
                    os.close(master)
                    if slave is not None:
                        os.close(slave)

    def test_apt_installs_only_missing_packages(self):
        for already, expected in [('', ['git', 'cmake']), ('git\n', ['cmake']), ('git\ncmake\n', [])]:
            with self.subTest(already=already):
                (self.work / 'installed').write_text(already)
                (self.work / 'calls').write_text('')
                result = self.bash(APT_MOCK + '\napt_install git cmake\napt_install git cmake')
                self.check_ok(result)
                calls = (self.work / 'calls').read_text().splitlines()
                self.assertEqual(calls, expected)

    def test_existing_app_skips_network_and_failed_download_keeps_cache(self):
        result = self.bash('installed() { return 0; }; install_app wechat wechat https://example.invalid/wechat.deb')
        self.check_ok(result)
        self.assertIn('已有跳过', result.stdout)
        result = self.bash('''
installed() { return 1; }
user_command() { return 1; }
apt_install() { :; }
printf old > "$CACHE_DIR/wechat.deb"
curl() {
    while (($#)); do
        if [[ $1 == --output ]]; then printf partial > "$2"; fi
        shift
    done
    return 22
}
install_app wechat wechat https://example.invalid/wechat.deb
printf SHOULD_NOT_RUN
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SHOULD_NOT_RUN', result.stdout)
        self.assertEqual((self.work / 'cache/wechat.deb').read_text(), 'old')
        self.assertEqual(list((self.work / 'cache').glob('*.part.*')), [])

    def test_shell_seeding_and_personal_config_preservation(self):
        home = self.work / 'home'
        home.mkdir()
        templates = ROOT / 'templates'
        configure(home, templates, 'first')
        first = (home / '.zshrc').read_text()
        self.assertEqual(first.count('useful-toolds/shell.zsh'), 1)
        self.assertIn('useful-toolds/prompt.zsh', first)
        prompt = home / '.config/starship.toml'
        prompt.write_text('# My personal prompt\n')
        before = (home / '.zshrc').stat().st_mtime_ns
        self.assertEqual(configure(home, templates, 'second'), [])
        self.assertEqual((home / '.zshrc').stat().st_mtime_ns, before)
        self.assertEqual(prompt.read_text(), '# My personal prompt\n')
        personal_home = self.work / 'personal'
        personal_home.mkdir()
        original = 'source "$HOME/.oh-my-zsh/oh-my-zsh.sh"\nalias ll="ls -l"\n'
        (personal_home / '.zshrc').write_text(original)
        configure(personal_home, templates, 'first')
        self.assertIn(original, (personal_home / '.zshrc').read_text())
        self.assertNotIn('useful-toolds/prompt.zsh', (personal_home / '.zshrc').read_text())
        self.assertEqual((personal_home / '.local/state/useful-toolds/backups/first/.zshrc').read_text(), original)

    def test_default_shell_configured_even_when_zsh_exists(self):
        result = self.bash('''
getent() { printf 'tester:x:1000:1000::%s:/bin/bash\n' "$USER_HOME"; }
chsh() { printf '%s\n' "$*" >> "$TEST_ROOT/calls"; }
ensure_default_zsh
''')
        self.check_ok(result)
        self.assertIn('zsh tester', (self.work / 'calls').read_text())
        self.assertIn('待登录', result.stdout)

    def test_python_environment_preserved_and_only_missing_library_added(self):
        home = self.work / 'user'
        env_dir = home / '.venvs/dev'
        subprocess.run(['/usr/bin/python3', '-m', 'venv', '--without-pip', str(env_dir)], check=True, capture_output=True)
        site = next((env_dir / 'lib').glob('python*/site-packages'))
        (env_dir / 'personal.txt').write_text('keep')
        (site / 'numpy.py').write_text('')
        dist = site / 'numpy-1.0.dist-info'
        dist.mkdir()
        (dist / 'METADATA').write_text('Metadata-Version: 2.1\nName: numpy\nVersion: 1.0\n')
        # Local fake pip supplies only the missing fixture package; it cannot use network.
        (site / 'pip.py').write_text('''import pathlib, sys
root = pathlib.Path(__file__).parent
if sys.argv[1] == 'install':
    assert sys.argv[2:] == ['pyserial'], sys.argv
    (root / 'serial.py').write_text('')
    dist = root / 'pyserial-1.0.dist-info'
    dist.mkdir()
    (dist / 'METADATA').write_text('Metadata-Version: 2.1\\nName: pyserial\\nVersion: 1.0\\n')
    (root / 'installed.txt').write_text('pyserial')
''')
        result = self.bash('''
universe_install() { :; }
as_user() { "$@"; }
ensure_dev_env
pip_missing numpy:numpy pyserial:serial
pip_missing numpy:numpy pyserial:serial
''')
        self.check_ok(result)
        self.assertEqual((site / 'installed.txt').read_text(), 'pyserial')
        self.assertEqual((env_dir / 'personal.txt').read_text(), 'keep')

    def test_docker_only_adds_missing_compose_for_existing_source(self):
        for flavor, compose in [('docker-ce', 'docker-compose-plugin'), ('docker.io', 'docker-compose-v2')]:
            with self.subTest(flavor=flavor):
                (self.work / 'installed').write_text(f'{flavor}\ndocker-ce-cli\ncontainerd.io\n')
                (self.work / 'calls').write_text('')
                body = APT_MOCK + f'''
universe_install() {{ apt_install "$@"; }}
ensure_docker_repository() {{ :; }}
ensure_group() {{ :; }}
systemctl() {{ :; }}
docker() {{ :; }}
as_user() {{
    if [[ "$*" == 'docker compose version' ]]; then installed {compose}; else return 0; fi
}}
module_docker
'''
                result = self.bash(body)
                self.check_ok(result)
                self.assertEqual((self.work / 'calls').read_text().splitlines(), [compose])

    def test_failure_isolated_and_dependent_module_blocked(self):
        result = self.bash('''
MODULES=(base shell terminal python)
module_base() { event 已有跳过 base; }
module_shell() { false; printf SHOULD_NOT_RUN; }
module_terminal() { printf SHOULD_NOT_RUN; }
module_python() { event 安装完成 python; }
run_modules
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SHOULD_NOT_RUN', result.stdout)
        self.assertIn('安装完成\tpython', (self.work / 'events').read_text())
        self.assertIn('依赖 shell 未完成', result.stdout)
        self.assertIn('--only shell,terminal', result.stdout)

    def test_docker_merge_preserves_runtime_and_custom_options(self):
        original = {'runtimes': {'nvidia': {'path': 'nvidia-container-runtime', 'runtimeArgs': []}},
                    'data-root': '/data/docker', 'log-opts': {'max-size': '20m'},
                    'registry-mirrors': ['https://existing.example']}
        merged = merge(original, ['https://new.example', 'https://new.example'])
        self.assertEqual(merged['runtimes'], original['runtimes'])
        self.assertEqual(merged['log-opts']['max-size'], '20m')
        self.assertEqual(merged['data-root'], '/data/docker')
        self.assertEqual(len(merged['registry-mirrors']), 2)
        self.assertEqual(merge(merged, ['https://new.example']), merged)
        self.assertNotIn('log-opts', merge({'log-driver': 'journald'}, []))
        with self.assertRaises(ValueError):
            merge([], [])

    def test_docker_restart_failure_restores_config(self):
        config = self.work / 'daemon.json'
        config.write_text('{"data-root":"/keep"}\n')
        original = config.read_bytes()
        result = self.bash('''
dockerd() { :; }
systemctl() {
    printf 'restart\n' >> "$TEST_ROOT/calls"
    [[ $(wc -l < "$TEST_ROOT/calls") -gt 1 ]]
}
apply_daemon_config "$TEST_ROOT/daemon.json"
''', source='scripts/docker/configure_daemon.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(config.read_bytes(), original)
        self.assertEqual((self.work / 'calls').read_text().splitlines(), ['restart', 'restart'])
        config.write_text('{broken')
        result = self.bash('apply_daemon_config "$TEST_ROOT/daemon.json"', source='scripts/docker/configure_daemon.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(config.read_text(), '{broken')
        self.assertNotIn('UNEXPECTED', result.stderr)

    @unittest.skipUnless(importlib.util.find_spec('gi'), 'GSettings test requires the Ubuntu python3-gi package')
    def test_terminal_and_input_settings_preserved_with_memory_backend(self):
        code = '''
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from gi.repository import Gio, GLib
from configure_desktop import terminal, chinese, PROFILE_ID
from config_files import ConfigFiles
files = ConfigFiles(*sys.argv[2:])
terminal(files, Gio, GLib)
settings = Gio.Settings.new('org.gnome.Terminal.ProfilesList')
assert settings.get_string('default') == PROFILE_ID
profile = Gio.Settings.new_with_path('org.gnome.Terminal.Legacy.Profile', f'/org/gnome/terminal/legacy/profiles:/:{PROFILE_ID}/')
assert not profile.get_boolean('use-custom-command')
profile.set_string('font', 'Monospace 17')
settings.set_string('default', 'personal')
files.changed.clear()
terminal(files, Gio, GLib)
assert not files.changed
assert profile.get_string('font') == 'Monospace 17'
assert settings.get_string('default') == 'personal'
xsettings = Gio.Settings.new('org.gnome.settings-daemon.plugins.xsettings')
xsettings.set_value('overrides', GLib.Variant('a{sv}', {'Other': GLib.Variant('i', 42)}))
chinese(files, Gio, GLib)
assert xsettings.get_value('overrides').unpack() == {'Other': 42, 'Gtk/IMModule': 'fcitx'}
(files.home / '.config/fcitx5/conf/pinyin.conf').write_text('PageSize=9\\n')
files.changed.clear()
chinese(files, Gio, GLib)
assert not files.changed
assert (files.home / '.config/fcitx5/conf/pinyin.conf').read_text() == 'PageSize=9\\n'
'''
        result = subprocess.run([sys.executable, '-c', code, str(HELPERS), str(self.work / 'home'),
                                 str(ROOT / 'templates'), 'test'], capture_output=True, text=True,
                                env={**os.environ, 'GSETTINGS_BACKEND': 'memory'}, timeout=10)
        self.check_ok(result)


APT_MOCK = '''
installed() { grep -Fxq "$1" "$TEST_ROOT/installed"; }
apt_refresh() { :; }
apt-get() {
    local argument capture=0
    for argument in "$@"; do
        if [[ $argument == -y ]]; then capture=1; continue; fi
        if ((capture)); then
            printf '%s\\n' "$argument" >> "$TEST_ROOT/installed"
            printf '%s\\n' "$argument" >> "$TEST_ROOT/calls"
        fi
    done
}
'''

if __name__ == '__main__':
    unittest.main()
