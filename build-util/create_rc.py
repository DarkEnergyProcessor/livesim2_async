import argparse

import version_extract


def get_rc_string(ver: version_extract.DEPLSVersion):
    return f"""LANGUAGE LANG_NEUTRAL, SUBLANG_NEUTRAL

1 ICON "livesim2.ico"

1 VERSIONINFO
FILEVERSION {ver.major},{ver.minor},{ver.patch},0
PRODUCTVERSION {ver.major},{ver.minor},{ver.patch},0
FILEOS 0x40004
FILETYPE 0x1
{{
BLOCK "StringFileInfo"
{{
	BLOCK "040904b0"
	{{
		VALUE "FileDescription", "Live Simulator: 2"
		VALUE "FileVersion", "{ver.textual}"
		VALUE "CompanyName", "Dark Energy Processor Corporation"
		VALUE "LegalCopyright", "Copyright © 2041 Dark Energy Processor"
		VALUE "ProductName", "{ver.codename}"
		VALUE "ProductVersion", "{ver.textual}"
		VALUE "InternalName", "livesim2"
		VALUE "OriginalFilename", "lovec.exe"
	}}
}}

BLOCK "VarFileInfo"
{{
	VALUE "Translation", 0x0000 0x04E4
}}
}}

1 Manifest "livesim2.manifest"
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("main_lua")
    parser.add_argument("output")
    args = parser.parse_args()

    with open(args.main_lua, "r", encoding="UTF-8") as f:
        version = version_extract.depls_version(f.read(4096))

    with open(args.output, "w", encoding="UTF-8", newline="\r\n") as f:
        f.write(get_rc_string(version))


if __name__ == "__main__":
    main()
