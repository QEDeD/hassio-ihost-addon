"""Validate pinned flasher argument parsing without invoking any device action."""
import asyncio
from unittest.mock import AsyncMock, patch
from universal_silabs_flasher import flash
from universal_silabs_flasher.const import ApplicationType, ResetTarget

options = ["--device", "/dev/serial/by-id/TEST-NOT-A-DEVICE", "--bootloader-reset", "rts_dtr", "--probe-methods", "bootloader:115200,cpc:115200"]
async def check(argv):
    with patch.object(flash, "Flasher") as factory, patch.object(flash, "_cmd_flash", new_callable=AsyncMock) as action:
        await flash.main(argv)
        factory.assert_called_once_with(device="/dev/serial/by-id/TEST-NOT-A-DEVICE", probe_methods=[(ApplicationType("bootloader"),115200),(ApplicationType("cpc"),115200)], bootloader_reset=(ResetTarget("rts_dtr"),))
        action.assert_awaited_once()
        assert action.await_args.args[0].firmware == "/bundle/firmware/candidate.gbl"
async def main():
    await check(options + ["flash", "--firmware", "/bundle/firmware/candidate.gbl"])
    await check(["flash"] + options + ["--firmware", "/bundle/firmware/candidate.gbl"])
    print("PASS: options before and after flash preserve exact device, baud/probes, reset and firmware arguments; hardware action mocked")
asyncio.run(main())
