import argparse
import re
import sys

import version_extract

APP_VERSIONCODE = re.compile(r"app.version_code=\d+")
APP_VERSIONNAME = re.compile(r"app.version_name=.+")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mainlua")
    parser.add_argument("gradleprop")
    parser.add_argument("-o", "--output", type=str, default=None)
    args = parser.parse_args()

    with open(args.mainlua, "r", encoding="UTF-8") as f:
        depls_version = version_extract.depls_version(f.read())

    new_gradle_prop: list[str] = []
    with open(args.gradleprop, "r", encoding="ISO8859-1", newline="") as f:
        for line in f:
            newline = line.replace("\n", "").replace("\r", "")

            if re.match(APP_VERSIONCODE, newline):
                newline = f"app.version_code={depls_version.verint}"
            elif re.match(APP_VERSIONNAME, newline):
                newline = f"app.version_name={depls_version.textual}"

            new_gradle_prop.append(newline)

    gradle_prop_modded = "\n".join(new_gradle_prop)
    if args.output is not None:
        with open(args.output, "w", encoding="ISO8859-1") as f:
            f.write(gradle_prop_modded)
    else:
        sys.stdout.write(gradle_prop_modded)


if __name__ == "__main__":
    main()
