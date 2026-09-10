"""Convert existing gameplay recordings into Godot-native silent preview loops.

Usage: python3 scripts/encode_skill_previews.py --ffmpeg /path/to/ffmpeg
"""
import argparse
import subprocess
from pathlib import Path

SOURCES = {
    "grapple": "skills-recall",
    "repulse": "skills-polished",
    "rewind": "skills-recall",
    "vortex": "skills-polished",
    "chrono": "skills-field",
    "aegis": "skills-field",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    destination = root / "assets/skill_previews"
    destination.mkdir(parents=True, exist_ok=True)
    for skill, directory in SOURCES.items():
        source = root / "docs/screenshots" / directory / f"{skill}.mp4"
        output = destination / f"{skill}.ogv"
        subprocess.run([
            args.ffmpeg, "-v", "error", "-y", "-i", str(source), "-an",
            "-vf", "scale=960:540", "-c:v", "libtheora", "-q:v", "7",
            "-pix_fmt", "yuv420p", str(output),
        ], check=True)
        subprocess.run([
            args.ffmpeg, "-v", "error", "-i", str(output), "-f", "null", "-",
        ], check=True)
        print(f"{skill}: {output.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
