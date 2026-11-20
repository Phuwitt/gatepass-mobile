"""Copy current sources into a temporary, unsynced build workspace, without xattrs."""
from pathlib import Path
import shutil
import tempfile
root = Path(__file__).resolve().parent.parent
stage = Path(tempfile.mkdtemp(prefix="gatepass-ios-build-", dir="/private/tmp"))
for name in ("lib", "assets", "ios"):
    shutil.copytree(root / name, stage / name,
        ignore=shutil.ignore_patterns("Pods", ".symlinks", "ephemeral", "Flutter.podspec", "Generated.xcconfig", "flutter_export_environment.sh"),
        copy_function=shutil.copyfile)
for name in ("pubspec.yaml", "pubspec.lock"):
    shutil.copyfile(root / name, stage / name)
print(stage)
