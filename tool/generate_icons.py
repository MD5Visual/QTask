#!/usr/bin/env python3
"""
Generate platform specific launcher icons from task_app_logo.png.

This script avoids third party dependencies by including a very small PNG
decoder/encoder that only supports the format used by the provided logo
image (8-bit RGBA, non-interlaced). The same logic is then used to scale
the pixels for each target size using nearest-neighbour sampling.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class PNGImage:
    def __init__(self, width: int, height: int, pixels: bytearray):
        self.width = width
        self.height = height
        self.pixels = pixels


def _read_chunks(data: bytes):
    offset = 8
    end = len(data)
    while offset < end:
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk_data = data[offset + 8 : offset + 8 + length]
        offset += 12 + length
        yield chunk_type, chunk_data


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def _reconstruct_scanlines(raw: bytes, width: int, height: int) -> bytearray:
    stride = width * 4
    result = bytearray(height * stride)
    offset = 0
    prev_row = [0] * stride
    idx = 0
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        row = list(raw[offset : offset + stride])
        offset += stride
        recon = [0] * stride
        if filter_type == 0:
            recon = row
        elif filter_type == 1:
            for i in range(stride):
                left = recon[i - 4] if i >= 4 else 0
                recon[i] = (row[i] + left) & 0xFF
        elif filter_type == 2:
            for i in range(stride):
                up = prev_row[i]
                recon[i] = (row[i] + up) & 0xFF
        elif filter_type == 3:
            for i in range(stride):
                left = recon[i - 4] if i >= 4 else 0
                up = prev_row[i]
                recon[i] = (row[i] + ((left + up) >> 1)) & 0xFF
        elif filter_type == 4:
            for i in range(stride):
                left = recon[i - 4] if i >= 4 else 0
                up = prev_row[i]
                up_left = prev_row[i - 4] if i >= 4 else 0
                recon[i] = (row[i] + _paeth(left, up, up_left)) & 0xFF
        else:
            raise ValueError(f"Unsupported PNG filter type: {filter_type}")
        result[idx : idx + stride] = bytes(recon)
        idx += stride
        prev_row = recon
    return result


def decode_png(path: Path) -> PNGImage:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("Unsupported PNG signature")
    width = height = None
    bit_depth = color_type = interlace = None
    idat_parts: list[bytes] = []
    for chunk_type, chunk_data in _read_chunks(data):
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
        elif chunk_type == b"IDAT":
            idat_parts.append(chunk_data)
        elif chunk_type == b"IEND":
            break
    if width is None or height is None:
        raise ValueError("PNG missing IHDR chunk")
    if bit_depth != 8 or color_type != 6 or interlace != 0:
        raise ValueError("Only 8-bit RGBA non-interlaced PNGs are supported")
    decompressed = zlib.decompress(b"".join(idat_parts))
    pixels = _reconstruct_scanlines(decompressed, width, height)
    return PNGImage(width, height, pixels)


def _encode_png(image: PNGImage) -> bytes:
    stride = image.width * 4
    raw = bytearray()
    for y in range(image.height):
        raw.append(0)
        start = y * stride
        raw.extend(image.pixels[start : start + stride])
    compressed = zlib.compress(bytes(raw), 9)
    chunks = []

    def add_chunk(chunk_type: bytes, chunk_data: bytes):
        chunks.append(
            struct.pack(">I", len(chunk_data))
            + chunk_type
            + chunk_data
            + struct.pack(">I", zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)
    add_chunk(b"IHDR", ihdr)
    add_chunk(b"IDAT", compressed)
    add_chunk(b"IEND", b"")
    return PNG_SIGNATURE + b"".join(chunks)


def _resize(image: PNGImage, size: int) -> PNGImage:
    dst = bytearray(size * size * 4)
    for y in range(size):
        src_y = y * image.height // size
        for x in range(size):
            src_x = x * image.width // size
            src_idx = (src_y * image.width + src_x) * 4
            dst_idx = (y * size + x) * 4
            dst[dst_idx : dst_idx + 4] = image.pixels[src_idx : src_idx + 4]
    return PNGImage(size, size, dst)


def _write_png(path: Path, image: PNGImage):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_encode_png(image))


def _build_ico(images: list[tuple[int, bytes]]) -> bytes:
    header = struct.pack("<HHH", 0, 1, len(images))
    entries = []
    offset = 6 + 16 * len(images)
    for size, data in images:
        width_byte = size if size < 256 else 0
        entry = struct.pack(
            "<BBBBHHII", width_byte, width_byte, 0, 0, 1, 32, len(data), offset
        )
        entries.append(entry)
        offset += len(data)
    return header + b"".join(entries) + b"".join(data for _, data in images)


def main():
    project_root = Path(__file__).resolve().parents[1]
    source = project_root / "task_app_logo.png"
    base_image = decode_png(source)

    android_targets = {
        "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
        "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
        "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
        "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    ios_targets = {
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png": 20,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png": 40,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png": 60,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png": 29,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png": 58,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png": 87,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png": 40,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png": 80,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png": 120,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png": 120,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png": 180,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png": 76,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png": 152,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png": 167,
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png": 1024,
    }
    web_targets = {
        "web/favicon.png": 64,
        "web/icons/Icon-192.png": 192,
        "web/icons/Icon-512.png": 512,
        "web/icons/Icon-maskable-192.png": 192,
        "web/icons/Icon-maskable-512.png": 512,
    }

    for rel_path, size in (
        list(android_targets.items())
        + list(ios_targets.items())
        + list(web_targets.items())
    ):
        resized = _resize(base_image, size)
        _write_png(project_root / rel_path, resized)

    ico_sizes = [16, 32, 48, 64, 128, 256]
    ico_images = []
    for size in ico_sizes:
        resized = _resize(base_image, size)
        ico_images.append((size, _encode_png(resized)))
    (project_root / "windows/runner/resources").mkdir(parents=True, exist_ok=True)
    (project_root / "windows/runner/resources/app_icon.ico").write_bytes(
        _build_ico(ico_images)
    )


if __name__ == "__main__":
    main()
