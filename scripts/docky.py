#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "typer>=0.12",
#     "loguru>=0.7",
# ]
# ///
"""Build, sign, and deploy Docky locally with a stable signing identity.

macOS permissions (Accessibility, Screen Recording, Automation, ...) are
bound to the app's TeamIdentifier. Re-signing every build with the same
Developer ID keeps that identifier stable, so permissions survive
rebuilds. An ad-hoc signature would change every build and re-prompt.

Deploys also disable Sparkle's automatic update checks: otherwise the
updater replaces a dev build with the latest official release
(the updater runs as a separate process and wins the race).
Re-enable with `docky.py updates --enable`.
"""

from __future__ import annotations

import hashlib
import os
import subprocess
import time
from pathlib import Path

import typer
from loguru import logger

app = typer.Typer(no_args_is_help=True)

REPO = Path(__file__).resolve().parent.parent
PROJECT = REPO / "Docky.xcodeproj"
SCHEME = "Docky"
BUNDLE_ID = "gt.quintero.Docky"
INSTALLED_APP = Path("/Applications/Docky.app")
BUILD_DIR = REPO / "build" / "dd-dev"
ENTITLEMENTS_CACHE = BUILD_DIR / "docky-entitlements.plist"
DEFAULT_IDENTITY = os.environ.get(
    "DOCKY_SIGN_IDENTITY",
    "Developer ID Application: Tobias Hochguertel (4ANN77GFL4)",
)


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    logger.debug("{}", " ".join(cmd))
    return subprocess.run(cmd, check=True, text=True, capture_output=True, **kwargs)


def built_app(config: str) -> Path:
    return BUILD_DIR / "Build" / "Products" / config / "Docky.app"


def md5_of(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def team_identifier(app_path: Path) -> str | None:
    try:
        proc = subprocess.run(
            ["codesign", "-dvv", str(app_path)],
            text=True, capture_output=True, check=False,
        )
    except FileNotFoundError:
        return None
    for line in (proc.stderr + proc.stdout).splitlines():
        if line.startswith("TeamIdentifier="):
            value = line.split("=", 1)[1].strip()
            return None if value == "not signed" else value
    return None


def ensure_entitlements() -> Path:
    if ENTITLEMENTS_CACHE.exists():
        return ENTITLEMENTS_CACHE
    if not INSTALLED_APP.exists():
        raise typer.BadParameter(
            f"No cached entitlements at {ENTITLEMENTS_CACHE} and "
            f"{INSTALLED_APP} is missing to extract them from."
        )
    ENTITLEMENTS_CACHE.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(INSTALLED_APP)],
        check=True, text=True, capture_output=True,
    )
    ENTITLEMENTS_CACHE.write_text(proc.stdout)
    logger.info("Extracted entitlements from {} to {}", INSTALLED_APP, ENTITLEMENTS_CACHE)
    return ENTITLEMENTS_CACHE


def sign_app(app_path: Path, identity: str) -> None:
    identities = subprocess.run(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        text=True, capture_output=True, check=False,
    ).stdout
    if identity not in identities:
        raise typer.BadParameter(
            f"Signing identity '{identity}' not found in keychain.\n{identities}"
        )
    entitlements = ensure_entitlements()
    run([
        "codesign", "--deep", "--force", "--options", "runtime",
        "--entitlements", str(entitlements), "--sign", identity, str(app_path),
    ])
    run(["codesign", "--verify", "--deep", "--strict", str(app_path)])
    logger.info("Signed {} as {} (team {})", app_path, identity, team_identifier(app_path))


@app.command()
def build(
    config: str = typer.Option("Debug", help="Xcode build configuration."),
    identity: str = typer.Option(DEFAULT_IDENTITY, help="Codesigning identity for the re-sign step."),
) -> None:
    """Build Docky and re-sign the bundle with the stable identity."""
    run([
        "xcodebuild", "build",
        "-project", str(PROJECT), "-scheme", SCHEME, "-configuration", config,
        "-destination", "platform=macOS",
        "-derivedDataPath", str(BUILD_DIR),
        "CODE_SIGN_IDENTITY=-", "CODE_SIGNING_REQUIRED=NO",
    ])
    app_path = built_app(config)
    if not app_path.exists():
        raise typer.Exit(f"Build produced no bundle at {app_path}")
    sign_app(app_path, identity)
    logger.info("Build ready at {}", app_path)


def docky_pids() -> list[str]:
    proc = subprocess.run(["pgrep", "-f", "/Applications/Docky.app/Contents/MacOS/Docky"],
                          text=True, capture_output=True, check=False)
    return [pid for pid in proc.stdout.split() if pid]


def quit_docky() -> None:
    subprocess.run(["osascript", "-e", 'tell application "Docky" to quit'],
                   capture_output=True, check=False)
    for _ in range(30):
        if not docky_pids():
            return
        time.sleep(0.5)
    raise typer.Exit("Docky did not quit within 15s; aborting deploy.")


def kill_strays() -> None:
    for pattern in ["mediaremote-adapter.pl", "Sparkle/.*/Updater.app", "Autoupdate"]:
        proc = subprocess.run(["pgrep", "-f", pattern],
                              text=True, capture_output=True, check=False)
        for pid in proc.stdout.split():
            logger.debug("Killing stray process {} ({})", pid, pattern)
            subprocess.run(["kill", pid], capture_output=True, check=False)


def launch_and_confirm() -> None:
    subprocess.run(["open", str(INSTALLED_APP)], check=True)
    for _ in range(20):
        if docky_pids():
            logger.info("Docky relaunched from {}", INSTALLED_APP)
            return
        time.sleep(0.5)
    raise typer.Exit("Docky did not relaunch; check Console.app.")


def restart_app() -> None:
    quit_docky()
    kill_strays()
    launch_and_confirm()


def debug_log_file() -> Path:
    return Path.home() / "Library/Logs/Docky/docky-debug.log"


@app.command()
def deploy(
    config: str = typer.Option("Debug", help="Which local build to install."),
    identity: str = typer.Option(DEFAULT_IDENTITY, help="Expected signing identity."),
) -> None:
    """Install a local build to /Applications and relaunch it."""
    app_path = built_app(config)
    if not app_path.exists():
        raise typer.Exit(f"No local build at {app_path}; run `build` first.")
    previous_team = team_identifier(INSTALLED_APP) if INSTALLED_APP.exists() else None
    new_team = team_identifier(app_path)
    if new_team is None:
        raise typer.Exit(f"{app_path} is not signed; run `build` first.")

    quit_docky()
    kill_strays()
    run(["defaults", "write", BUNDLE_ID, "SUEnableAutomaticChecks", "-bool", "NO"])
    logger.info("Disabled Sparkle automatic checks (re-enable with `updates --enable`).")
    run(["ditto", str(app_path), str(INSTALLED_APP)])

    installed_binary = INSTALLED_APP / "Contents/MacOS/Docky"
    if md5_of(installed_binary) != md5_of(app_path / "Contents/MacOS/Docky"):
        raise typer.Exit("Installed binary differs from the built one; deploy failed.")
    run(["codesign", "--verify", "--deep", "--strict", str(INSTALLED_APP)])
    logger.info("Verified signature of {}", INSTALLED_APP)

    if previous_team != new_team:
        logger.warning(
            "TeamIdentifier changed {} -> {}. macOS will ask once to re-grant "
            "Accessibility / Screen Recording / Automation permissions; afterwards "
            "they stay granted as long as this identity is reused.",
            previous_team, new_team,
        )

    subprocess.run(["open", str(INSTALLED_APP)], check=True)
    for _ in range(20):
        if docky_pids():
            logger.info("Docky relaunched from {}", INSTALLED_APP)
            return
        time.sleep(0.5)
    raise typer.Exit("Docky did not relaunch; check Console.app.")


@app.command()
def logs(
    tail: int = typer.Option(0, help="Print the last N lines instead of just the path."),
    clear: bool = typer.Option(False, help="Clear the log file."),
) -> None:
    """Show the debug log file, optionally its tail."""
    path = debug_log_file()
    if clear:
        if path.exists():
            path.unlink()
        logger.info("Cleared {}", path)
        return
    if tail > 0:
        if not path.exists():
            logger.info("No log file yet at {}", path)
            return
        proc = subprocess.run(["tail", f"-{tail}", str(path)],
                              text=True, capture_output=True, check=False)
        print(proc.stdout, end="")
        return
    print(path)


@app.command()
def restart() -> None:
    """Quit and relaunch the installed app (no rebuild)."""
    restart_app()


@app.command()
def debug(
    enable: bool = typer.Option(True, "--enable/--disable", help="Write diagnostics to the log file."),
) -> None:
    """Toggle debug file logging. Takes effect immediately, no restart."""
    run(["defaults", "write", BUNDLE_ID, "docky.debugLoggingEnabled",
         "-bool", "YES" if enable else "NO"])
    logger.info("Debug logging {}", "enabled" if enable else "disabled")


@app.command()
def layout() -> None:
    """Print the latest machine-readable layout snapshot as JSON."""
    path = debug_log_file().parent / "docky-layout.json"
    if not path.exists():
        raise typer.Exit(f"No snapshot yet at {path}; enable debug logging first.")
    print(path.read_text(), end="")


@app.command()
def overlay(
    enable: bool = typer.Option(True, "--enable/--disable", help="Paint the technical overlay over dock tiles."),
) -> None:
    """Toggle the layout overlay. Restarts the app to apply."""
    run(["defaults", "write", BUNDLE_ID, "docky.showsLayoutOverlay",
         "-bool", "YES" if enable else "NO"])
    restart_app()


@app.command()
def redeploy(
    config: str = typer.Option("Debug", help="Xcode build configuration."),
    identity: str = typer.Option(DEFAULT_IDENTITY, help="Codesigning identity."),
) -> None:
    """Build, sign, and deploy in one step."""
    build(config=config, identity=identity)
    deploy(config=config, identity=identity)


@app.command()
def updates(enable: bool = typer.Option(False, help="Re-enable Sparkle automatic checks.")) -> None:
    """Toggle Sparkle automatic update checks for the installed app."""
    run(["defaults", "write", BUNDLE_ID, "SUEnableAutomaticChecks",
         "-bool", "YES" if enable else "NO"])
    logger.info("Sparkle automatic checks {}", "enabled" if enable else "disabled")


if __name__ == "__main__":
    app()
