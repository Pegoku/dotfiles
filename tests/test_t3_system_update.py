import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/t3-system-update"


class UpdateTests(unittest.TestCase):
    def run_update(self, mode="sync", version="0.0.45-1", package_exit=0,
                   update_exit=0, installed=True):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "calls"
            commands = {
                "pacman": 'echo "pacman $*" >> "$CALLS"\n'
                          + (f'echo "t3code-bin {version}"\n' if installed else "exit 1\n"),
                "yay": f'echo "yay $*" >> "$CALLS"\nexit {package_exit}\n',
                "t3": 'echo "t3 $*" >> "$CALLS"\n'
                      'if [ "$1" = --version ]; then echo 0.0.42; exit 0; fi\n'
                      f'exit {update_exit}\n',
            }
            for name, body in commands.items():
                path = root / name
                path.write_text("#!/bin/sh\n" + body)
                path.chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}",
                       T3_UPDATE_BIN=str(root / "t3"), CALLS=str(log))
            result = subprocess.run([str(SCRIPT), mode], env=env,
                                    capture_output=True, text=True)
            return result, log.read_text() if log.exists() else ""

    def test_pins_update_to_desktop_release(self):
        result, calls = self.run_update(version="1:0.0.45-2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("t3 update 0.0.45 --yes", calls)

    def test_yay_runs_before_service_update(self):
        result, calls = self.run_update(mode="yay")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertLess(calls.index("yay "), calls.index("t3 update"))
        self.assertIn("--nosudoloop -Syu --devel", calls)

    def test_failed_package_update_does_not_restart_service(self):
        result, calls = self.run_update(mode="yay", package_exit=7)
        self.assertEqual(result.returncode, 7)
        self.assertNotIn("t3 ", calls)

    def test_missing_desktop_package_is_skipped(self):
        result, calls = self.run_update(installed=False)
        self.assertEqual(result.returncode, 0)
        self.assertNotIn("t3 ", calls)

    def test_development_package_version_is_rejected(self):
        result, calls = self.run_update(version="0.0.45.r12-1")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("t3 update", calls)

    def test_download_failure_is_reported(self):
        result, _ = self.run_update(update_exit=9)
        self.assertEqual(result.returncode, 9)


if __name__ == "__main__":
    unittest.main()
