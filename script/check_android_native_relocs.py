#!/usr/bin/env python3
"""校验 APK 内的 native 库不含旧 Android linker 不支持的压缩重定位。

DT_RELR(0x6fffe000) 只有 Android 10+ 的 linker 会处理；更早的版本会整表跳过，
导致 .init_array/.got 保持未重定位的值，加载即 SIGSEGV。
"""

from __future__ import annotations

import os
import struct
import sys
import zipfile

DT_RELR = 0x6FFFE000
PT_DYNAMIC = 2
ELFCLASS32 = 1

# 同一份 RELR 表有两套 tag：NDK r29 输出 Android 私有值，较新的 ELF 标准值是 0x23/0x24。
RELR_START_TAGS = {DT_RELR, 0x23}


def dynamic_tags(blob: bytes) -> set[int]:
    if len(blob) < 64 or blob[:4] != b"\x7fELF":
        raise ValueError("not an ELF file")
    is_64 = blob[4] == 2
    endian = "<" if blob[5] == 1 else ">"
    if blob[4] != ELFCLASS32 and not is_64:
        raise ValueError("unsupported ELF class")

    if is_64:
        e_phoff = struct.unpack_from(endian + "Q", blob, 0x20)[0]
        e_phentsize, e_phnum = struct.unpack_from(endian + "HH", blob, 0x36)
    else:
        e_phoff = struct.unpack_from(endian + "I", blob, 0x1C)[0]
        e_phentsize, e_phnum = struct.unpack_from(endian + "HH", blob, 0x2A)

    tags: set[int] = set()
    for i in range(e_phnum):
        base = e_phoff + i * e_phentsize
        p_type = struct.unpack_from(endian + "I", blob, base)[0]
        if p_type != PT_DYNAMIC:
            continue
        if is_64:
            p_offset = struct.unpack_from(endian + "Q", blob, base + 0x08)[0]
            p_filesz = struct.unpack_from(endian + "Q", blob, base + 0x20)[0]
            entry = endian + "QQ"
        else:
            p_offset = struct.unpack_from(endian + "I", blob, base + 0x04)[0]
            p_filesz = struct.unpack_from(endian + "I", blob, base + 0x10)[0]
            entry = endian + "II"

        size = struct.calcsize(entry)
        for off in range(0, p_filesz - size + 1, size):
            tag = struct.unpack_from(entry, blob, p_offset + off)[0]
            if tag == 0:
                break
            tags.add(tag)
    return tags


def iter_members(path: str):
    if path.lower().endswith(".apk"):
        with zipfile.ZipFile(path) as zf:
            for info in zf.infolist():
                if info.filename.endswith(".so"):
                    yield info.filename, zf.read(info)
    else:
        with open(path, "rb") as fh:
            yield path, fh.read()


def main(argv: list[str]) -> int:
    if not argv:
        print("用法: check_android_native_relocs.py <apk|.so> [...]", file=sys.stderr)
        return 2

    bad: list[str] = []
    for path in argv:
        if not os.path.exists(path):
            print(f"❌ 找不到产物: {path}", file=sys.stderr)
            return 2
        for name, blob in iter_members(path):
            try:
                tags = dynamic_tags(blob)
            except ValueError as err:
                print(f"跳过 {name}: {err}", file=sys.stderr)
                continue
            if RELR_START_TAGS & tags:
                bad.append(name)
                print(f"❌ {name}: 含 DT_RELR 压缩重定位，Android 10 以下无法加载")

    if bad:
        print(
            f"\n发现 {len(bad)} 个不兼容产物。请为 Rust 链接加上 "
            "`-Wl,--pack-dyn-relocs=android`（见 rust/build.rs）。",
            file=sys.stderr,
        )
        return 1

    print("✅ native 库重定位格式对所有受支持 API 级别均可加载")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
