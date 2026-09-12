#!/usr/bin/env python3
"""Merge daemon settings without touching the system. The caller validates/applies."""
import argparse
import json
from pathlib import Path
from urllib.parse import urlsplit


def merge(current, mirrors):
    if not isinstance(current, dict):
        raise ValueError('daemon.json 顶层必须是对象')
    result = json.loads(json.dumps(current))
    driver = result.setdefault('log-driver', 'json-file')
    if driver == 'json-file':
        options = result.setdefault('log-opts', {})
        if not isinstance(options, dict):
            raise ValueError('log-opts 必须是对象')
        options.setdefault('max-size', '100m')
        options.setdefault('max-file', '3')
    result.setdefault('exec-opts', ['native.cgroupdriver=systemd'])
    if mirrors:
        existing = result.setdefault('registry-mirrors', [])
        if not isinstance(existing, list) or not all(isinstance(x, str) for x in existing):
            raise ValueError('registry-mirrors 必须是字符串数组')
        for mirror in mirrors:
            url = urlsplit(mirror)
            if url.scheme not in ('http', 'https') or not url.hostname or url.username or url.password:
                raise ValueError('镜像地址需为有效 HTTP(S) URL，不包含账号密码')
            if mirror not in existing:
                existing.append(mirror)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--mirror', action='append', default=[])
    args = parser.parse_args()
    original = args.input.read_text() if args.input.exists() else '{}\n'
    current = json.loads(original)
    result = merge(current, args.mirror)
    text = original if current == result else json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.write_text(text)
    else:
        print(text, end='')


if __name__ == '__main__':
    main()
