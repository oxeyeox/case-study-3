
import csv
from pathlib import Path

DATA_DIR = Path("data/raw")


def inspect_csv(file_path: Path) -> None:
    print("\n" + "=" * 80)
    print(f"FILE: {file_path.relative_to(DATA_DIR)}")
    print(f"SIZE: {file_path.stat().st_size:,} bytes")

    try:
        with file_path.open(
            "r",
            encoding="utf-8-sig",
            newline=""
        ) as file:
            reader = csv.DictReader(file, delimiter=";")

            print(f"COLUMNS: {reader.fieldnames}")

            row_count = 0
            samples = []

            for row in reader:
                row_count += 1

                if len(samples) < 2:
                    samples.append(row)

            print(f"DATA ROWS: {row_count:,}")

            for index, sample in enumerate(samples, start=1):
                print(f"SAMPLE {index}: {sample}")

    except Exception as error:
        print(f"ERROR: {error}")


def main() -> None:
    if not DATA_DIR.exists():
        raise FileNotFoundError(
            f"Dataset directory not found: {DATA_DIR.resolve()}"
        )

    csv_files = sorted(DATA_DIR.rglob("*.csv"))

    if not csv_files:
        print(f"No CSV files found in {DATA_DIR.resolve()}")
        return

    print(f"Dataset directory: {DATA_DIR.resolve()}")
    print(f"CSV files found: {len(csv_files)}")

    for file_path in csv_files:
        inspect_csv(file_path)


if __name__ == "__main__":
    main()