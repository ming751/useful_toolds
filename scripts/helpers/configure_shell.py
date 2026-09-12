#!/usr/bin/env python3
import re
import sys
from config_files import ConfigFiles


def configure(home, templates, run_id):
    files = ConfigFiles(home, templates, run_id)
    zshrc = files.home / '.zshrc'
    original = zshrc.read_text() if zshrc.exists() else ''
    lines = {name: f'source "$HOME/.config/useful-toolds/{name}.zsh"'
             for name in ('shell', 'plugins', 'prompt')}
    personal = '\n'.join(line for line in original.splitlines()
                         if line.strip() not in lines.values() and not line.lstrip().startswith('#'))
    # Treat externally sourced configurations as personal too; never replace their theme.
    custom_theme = re.search(
        r'starship\s+init|oh-my-zsh|oh-my-posh|powerlevel|ZSH_THEME|'
        r'(?m:^\s*(?:export\s+)?(?:PROMPT|PS1|RPROMPT)\s*=)|'
        r'(?m:^\s*(?:source|\.)\s+)|(?m:^\s*prompt\s+)', personal)
    for name in ('shell', 'plugins'):
        files.seed(f'{name}.zsh', f'.config/useful-toolds/{name}.zsh')
    files.seed('starship.toml', '.config/starship.toml')
    text = original
    if lines['shell'] not in {line.strip() for line in text.splitlines()}:
        text = lines['shell'] + '\n' + text
    if lines['plugins'] not in {line.strip() for line in text.splitlines()}:
        text = text.rstrip('\n') + '\n' + lines['plugins'] + '\n'
    if not custom_theme or lines['prompt'] in original.splitlines():
        files.seed('prompt.zsh', '.config/useful-toolds/prompt.zsh')
        if lines['prompt'] not in {line.strip() for line in text.splitlines()}:
            text = text.rstrip('\n') + '\n' + lines['prompt'] + '\n'
    files.write(zshrc, text)
    return files.changed


if __name__ == '__main__':
    print('、'.join(configure(*sys.argv[1:4])), end='')
