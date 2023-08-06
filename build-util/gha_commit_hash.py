import os
import subprocess


def main():
    process = subprocess.run(["git", "rev-parse", "HEAD"], stdout=subprocess.PIPE, encoding="UTF-8")
    commit = process.stdout.strip()
    print("Commit:", commit)
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="UTF-8") as f:
        f.write(f"commit={commit}\n")


if __name__ == "__main__":
    main()
