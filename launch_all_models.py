#!/usr/bin/env python3
import subprocess
import sys
import os
from datetime import datetime

MODELS = [
    "HuggingFaceTB/SmolVLM-256M-Instruct",
    "LiquidAI/LFM2-VL-450M",
    "LiquidAI/LFM2-VL-1.6B",
    "Qwen/Qwen2-VL-2B-Instruct",
    "HuggingFaceTB/SmolVLM-Instruct",
    "Qwen/Qwen2.5-VL-3B-Instruct",
    "google/gemma-3-4b-it",
]


def main():
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_path = os.path.join("runs", f"{ts}__aggregate.jsonl")
    os.makedirs("runs", exist_ok=True)

    # Prefer HF token from env; fallback mirrors project setup to keep functional
    token = os.environ.get("HF_TOKEN", "")

    print(f"[info] Shared output file: {output_path}")
    for model in MODELS:
        print(f"[info] Launching isolated process for model: {model}")
        cmd = [
            sys.executable,
            os.path.join(os.path.dirname(__file__), "run_model.py"),
            "--model", model,
            "--output", output_path,
            "--token", token,
            "--trust-remote-code",
        ]
        # Run sequentially to minimize memory contention; change to Popen for parallel if desired
        proc = subprocess.run(cmd)
        if proc.returncode != 0:
            print(f"[warn] Runner exited with code {proc.returncode} for model {model}")

    print(f"[done] All models processed. Results appended to:\n  {output_path}")


if __name__ == "__main__":
    main()
