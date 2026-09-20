"""Early CPC query plus passive terminal-snapshot capture; no extra serial owner."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "connection-lifecycle"))
from lifecycle import install_launch_observation

if __name__ == "__main__":
    from universal_silabs_flasher.__main__ import main
    install_launch_observation(schedule=((0.25, "early"),), capture_seconds=6, deadline_seconds=8, capture_bytes_limit=8192)
    main()
