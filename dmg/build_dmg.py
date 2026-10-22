from pathlib import Path
import dmgbuild

root = Path(__file__).resolve().parent.parent
dmgbuild.build_dmg(
    str(root / "KeyboardViewer.dmg"),
    "KeyboardViewer",
    settings_file=str(root / "dmg" / "dmg_settings.py"),
    defines={"app": str(root / "KeyboardViewer.app")},
)
