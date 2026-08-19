#!/usr/bin/env python3
"""Convert the generated transaction JSON array to JSON Lines for Hadoop."""

import argparse
import json
from pathlib import Path


def convert(input_path: Path, output_path: Path) -> int:
    with input_path.open("r", encoding="utf-8") as source:
        transactions = json.load(source)

    if not isinstance(transactions, list):
        raise ValueError("Expected the input file to contain a JSON array")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as target:
        for transaction in transactions:
            target.write(json.dumps(transaction, separators=(",", ":")))
            target.write("\n")

    return len(transactions)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert transactions.json into Hadoop-friendly JSON Lines."
    )
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    count = convert(args.input, args.output)
    print(f"Prepared {count} transactions in {args.output}")


if __name__ == "__main__":
    main()
