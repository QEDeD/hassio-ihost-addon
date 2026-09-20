"""Add the vendor protocol-crypto component to the unchanged HFXO diagnostic recipe."""
import pathlib
import sys
source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
s = source.read_text()
old = "--with EFR32MG21A020F768IM32,cpc_security_secondary,bootloader_interface"
assert s.count(old) == 1
assert "sli_protocol_crypto" not in s
assert "SL_CLOCK_MANAGER_HFXO_EN:1," in s
assert not target.exists()
target.write_text(s.replace(old, old + ",sli_protocol_crypto"))
print("Only recipe addition: vendor sli_protocol_crypto component")
