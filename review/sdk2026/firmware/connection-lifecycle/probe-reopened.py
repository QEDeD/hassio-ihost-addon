import argparse
import asyncio
import logging
from lifecycle import probe_reopened

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("device")
    args = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG, format="%(asctime)s %(name)s %(levelname)s %(message)s")
    result = asyncio.run(probe_reopened(args.device))
    raise SystemExit(0 if result["result"] == "reply" else 1)
