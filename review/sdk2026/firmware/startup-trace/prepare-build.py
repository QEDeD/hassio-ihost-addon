from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
needle = 'export ARM_GCC_DIR="$GCC" NINJA_EXE_PATH=/usr/bin/ninja'
assert s.count(needle) == 1
s = s.replace(needle, 'python3 /trace/instrument.py "$WORK"\n' + needle)
Path(sys.argv[2]).write_text(s)
