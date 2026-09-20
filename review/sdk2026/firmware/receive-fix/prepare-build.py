from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
needle = 'export ARM_GCC_DIR="$GCC" NINJA_EXE_PATH=/usr/bin/ninja'
if s.count(needle) != 1:
    raise RuntimeError("Pinned build hook changed")
s = s.replace(needle, 'python3 /snapshot/instrument.py "$WORK" "$SDK"\n' + needle)
Path(sys.argv[2]).write_text(s)
