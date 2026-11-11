#!/usr/bin/env python3
"""Bounded GoFish comparison for storage, network, logs, firmware and BIOS GETs."""
import subprocess
import tempfile
from pathlib import Path

from extended_fixtures import extended_expected, extended_routes
from extended_reference import COMMIT, FILES, EXTENDED_FILES, load_extended_routes
from hardware_fixtures import assert_hardware
from test_gofish import ENV, REPO, fixture, run_adapter


def main():
    public = load_extended_routes()
    synthetic = extended_routes()
    with tempfile.TemporaryDirectory(prefix="moonredfish-extended-") as tmp:
        binary = Path(tmp) / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."], cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        commands = {
            "moonredfish": ["moon", "run", "examples/compare", "--target", "native", "--"],
            "GoFish v0.27.0": [str(binary)],
        }
        for name, command in commands.items():
            for label, routes in (("DMTF", public), ("synthetic", synthetic)):
                with fixture(routes) as (endpoint, state):
                    assert_hardware(run_adapter(name, command, "extended", endpoint), extended_expected(routes), name + " " + label)
                    assert state["visited"] == set(routes), f"{name}: incomplete {label} route coverage: {sorted(set(routes) - state['visited'])}"
                    assert not state["unexpected"], f"{name}: unexpected or mutating request"
            print(f"{name}: storage/drives/volumes, network, logs, firmware and BIOS defined-field comparison passed")
        print(f"DMTF mockups@{COMMIT}: {len(FILES) + len(EXTENDED_FILES)} unchanged hashes; synthetic storage/adapters and paginated logs; no physical BMC claim")


if __name__ == "__main__":
    main()
