import dataclasses
import re

DEPLS_VERSION = re.compile(r"DEPLS_VERSION = \"(.+)\"")
DEPLS_VERSION_NUMBER = re.compile(r"DEPLS_VERSION_NUMBER = (\d+)")
DEPLS_VERSION_CODENAME = re.compile(r"DEPLS_VERSION_CODENAME = \"(.+)\"")


@dataclasses.dataclass
class DEPLSVersion:
    verint: int
    major: int
    minor: int
    patch: int
    textual: str
    codename: str


def depls_version(main_lua: str):
    group = re.search(DEPLS_VERSION, main_lua)
    if group is None:
        raise Exception('unable to extract "DEPLS_VERSION"')
    textual = group.group(1)

    group = re.search(DEPLS_VERSION_NUMBER, main_lua)
    if group is None:
        raise Exception('unable to extract "DEPLS_VERSION_NUMBER"')
    verint = int(group.group(1))

    group = re.search(DEPLS_VERSION_CODENAME, main_lua)
    if group is None:
        codename = ""
    else:
        codename = group.group(1)

    return DEPLSVersion(verint, verint // 1000000 % 10, verint // 10000 % 10, verint // 100 % 10, textual, codename)
