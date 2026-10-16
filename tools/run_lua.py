"""Run LuaJIT-compatible tests with the optional Lupa development dependency."""
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.dev' / 'python'))
try:
    from lupa.luajit21 import LuaRuntime
except ImportError:
    raise SystemExit('Install LuaJIT or install Lupa for Python: python -m pip install "lupa>=2,<3"')

if len(sys.argv) < 2:
    raise SystemExit('Usage: python tools/run_lua.py path/to/test.lua')
test = Path(sys.argv[1]).resolve()
os.chdir(ROOT)
lua = LuaRuntime(unpack_returned_tuples=True, encoding=None)
lua.globals().arg = lua.table_from({0: str(test).encode(), **{i: s.encode() for i, s in enumerate(sys.argv[2:], 1)}})
lua.execute(test.read_bytes(), name=('@' + str(test)).encode())
