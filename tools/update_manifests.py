"""Regenerate manifests for projects edited directly in this checkout."""
import argparse
import hashlib
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]


def runtime(path):
    rel = path.as_posix()
    return (path.name != 'manifest.txt' and not rel.endswith('.md')
            and not re.search(r'(^|/)tests/', rel)
            and not re.search(r'(^|/)tests[^/]*\.lua$', rel))


def manifest(project):
    directory = ROOT / 'plugins' / project
    header = directory / 'header.lua'
    source = header.read_text(encoding='utf-8-sig') if header.exists() else ''
    match = re.search(r'''version\s*=\s*['"]([^'"]+)['"]''', source)
    old = directory / 'manifest.txt'
    previous = old.read_text(encoding='utf-8') if old.exists() else ''
    version = match.group(1) if match else re.search(r'^version (.+)$', previous, re.M)
    if not isinstance(version, str):
        version = version.group(1) if version else 'unversioned'
    rows = [f'project {project}', f'version {version}', 'entry mf_entry.lua']
    if header.exists():
        rows.append('header header.lua')
    files = sorted(p for p in directory.rglob('*') if p.is_file()
                   and runtime(p.relative_to(directory)))
    for path in files:
        data = path.read_bytes()
        rows.append(f'file {len(data)} {hashlib.sha256(data).hexdigest()} {path.relative_to(directory).as_posix()}')
    body = '\n'.join(rows) + '\n'
    build = hashlib.sha256(body.encode()).hexdigest()[:16]
    return f'# mf-arthas-manifest 1\nbuild {build}\n{body}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', action='append', default=[])
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    names = args.project or [p.name for p in (ROOT / 'plugins').iterdir() if (p / 'main.lua').exists()]
    stale = []
    for name in sorted(names):
        if not re.fullmatch(r'[A-Za-z0-9_ -]+', name) or not (ROOT / 'plugins' / name / 'main.lua').exists():
            parser.error(f'Unknown project: {name}')
        path = ROOT / 'plugins' / name / 'manifest.txt'
        identity = ('-- Generated stable project identity.\nreturn ' + repr(name) + '\n').encode()
        project_file = path.parent / 'mf_project.lua'
        if args.check:
            if not project_file.exists() or project_file.read_bytes() != identity:
                stale.append(name + '/mf_project.lua')
        elif not project_file.exists() or project_file.read_bytes() != identity:
            project_file.write_bytes(identity)
        for shared in (ROOT / 'shared').glob('*.lua'):
            target = path.parent / shared.name
            if args.check:
                if not target.exists() or target.read_bytes() != shared.read_bytes():
                    stale.append(name + '/' + shared.name)
            elif not target.exists() or target.read_bytes() != shared.read_bytes():
                shutil.copyfile(shared, target)
        expected = manifest(name)
        if not path.exists() or path.read_bytes() != expected.encode():
            if args.check:
                stale.append(name)
            else:
                path.write_bytes(expected.encode())
                print(f'{name}: manifest updated')
    if stale:
        raise SystemExit('Stale manifests: ' + ', '.join(stale) + '. Run tools/update_manifests.py.')
    if args.check:
        print(f'{len(names)} manifests match source bytes and SHA-256 digests.')


if __name__ == '__main__':
    main()
