#!/usr/bin/env python3
"""Imprime el UDID de un simulador iPhone disponible (el más reciente)."""
import json
import subprocess

data = json.loads(
    subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True
    )
)
candidates = []
for runtime, devices in data["devices"].items():
    if "iOS" not in runtime:
        continue
    version = tuple(
        int(p) for p in runtime.rsplit("iOS-", 1)[-1].split("-") if p.isdigit()
    )
    for device in devices:
        if device["name"].startswith("iPhone"):
            candidates.append((version, device["name"], device["udid"]))
if not candidates:
    raise SystemExit("No hay simuladores iPhone disponibles")
candidates.sort()
print(candidates[-1][2])
