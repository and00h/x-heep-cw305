"""
Parse C float tensor declarations from a .c file and save each one as a .npy file.

Handles declarations of the form:
    static const float __attribute__((section(".important_stuff"))) tensor_NAME[d0][d1]...[dN] = { ... };

Usage:
    python c_tensor_to_npy.py model.c [output_dir]
"""

import re
import sys
import pathlib
import numpy as np


_DECL_RE = re.compile(
    r'(?:static\s+)?const\s+float\s+__attribute__\(\(section\("\.important_stuff"\)\)\)\s+(\w+)'
    r'((?:\s*\[\s*\d+\s*\])+)'          # one or more [dim] groups
    r'\s*='
)
_DIM_RE   = re.compile(r'\[\s*(\d+)\s*\]')
_FLOAT_RE = re.compile(r'[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?f?')


def _find_tensor_blocks(src: str):
    """Yield (name, shape, values_str) for every tensor in src."""
    pos = 0
    while True:
        m = _DECL_RE.search(src, pos)
        if m is None:
            break

        name  = m.group(1)
        shape = tuple(int(d) for d in _DIM_RE.findall(m.group(2)))

        # Walk forward to find the matching closing brace + semicolon
        start = src.index('{', m.end())
        depth, i = 0, start
        while i < len(src):
            if   src[i] == '{': depth += 1
            elif src[i] == '}': depth -= 1
            if depth == 0:
                break
            i += 1

        values_str = src[start : i + 1]
        pos = i + 1
        yield name, shape, values_str


def parse_file(path: str, out_dir: str = ".") -> None:
    src = pathlib.Path(path).read_text()
    out = pathlib.Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    found = 0
    for name, shape, values_str in _find_tensor_blocks(src):
        raw = [float(v.rstrip('f')) for v in _FLOAT_RE.findall(values_str)]

        expected = 1
        for d in shape: expected *= d

        if len(raw) != expected:
            print(f"  WARNING: {name} expected {expected} values, got {len(raw)} — skipping")
            continue

        arr = np.array(raw, dtype=np.float32).reshape(shape)
        dst = out / f"{name}.npy"
        np.save(dst, arr)
        print(f"  {name} {list(shape)} -> {dst}")
        found += 1

    if found == 0:
        print("No tensors found.")
    else:
        print(f"\nSaved {found} tensor(s) to '{out_dir}'.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    c_file  = sys.argv[1]
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "."
    parse_file(c_file, out_dir)
