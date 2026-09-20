"""Create one diagnostic override from the unchanged, hardware-tested CPC recipe."""
import hashlib
import pathlib
import sys
source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
text = source.read_text()
old = "SL_CLOCK_MANAGER_HFXO_CTUNE:128,"
new = "SL_CLOCK_MANAGER_HFXO_EN:1," + old
assert text.count(old) == 1
assert "SL_CLOCK_MANAGER_HFXO_EN:" not in text
assert not target.exists()
target.write_text(text.replace(old, new))
print("Base recipe SHA256:", hashlib.sha256(source.read_bytes()).hexdigest())
print("Only recipe change: add SL_CLOCK_MANAGER_HFXO_EN:1 to SLC configuration")
