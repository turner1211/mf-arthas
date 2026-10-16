"""Release checks shared by the local publisher, pre-push hook and CI."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
for command in [
    [sys.executable, 'tools/update_manifests.py', '--check'],
    [sys.executable, 'tools/run_lua.py', 'tools/test_loader.lua'],
    [sys.executable, 'tools/run_lua.py', 'tools/test_localization.lua'],
    [sys.executable, 'tools/run_lua.py', 'tools/test_audit.lua'],
]:
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode:
        raise SystemExit(result.returncode)
print('Release checks passed.')
