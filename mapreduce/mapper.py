#!/usr/bin/env python3
"""Map trade-finance transactions to aggregation keys."""

import json
import sys


def main() -> None:
    for line in sys.stdin:
        try:
            transaction = json.loads(line)
            product = transaction["product_type"]
            country = transaction["beneficiary_country"]
            currency = transaction["currency"]
            amount = float(transaction["amount"])
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            print("reporter:counter:Member2,Invalid transactions,1", file=sys.stderr)
            continue

        # Currency is part of the key so values in unlike currencies are not added.
        print(f"{product}|{country}|{currency}\t1\t{amount:.2f}")


if __name__ == "__main__":
    main()
