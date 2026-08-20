#!/usr/bin/env python3
"""Reduce transaction counts and values by product, country, and currency."""

import sys


def emit(key: str, count: int, total: float) -> None:
    product, country, currency = key.split("|", 2)
    print(f"{product}\t{country}\t{currency}\t{count}\t{total:.2f}")


def main() -> None:
    current_key = None
    transaction_count = 0
    total_value = 0.0

    for line in sys.stdin:
        try:
            key, count_text, amount_text = line.rstrip("\n").split("\t", 2)
            count = int(count_text)
            amount = float(amount_text)
        except ValueError:
            print("reporter:counter:Member2,Invalid mapper rows,1", file=sys.stderr)
            continue

        if current_key is not None and key != current_key:
            emit(current_key, transaction_count, total_value)
            transaction_count = 0
            total_value = 0.0

        current_key = key
        transaction_count += count
        total_value += amount

    if current_key is not None:
        emit(current_key, transaction_count, total_value)


if __name__ == "__main__":
    main()
