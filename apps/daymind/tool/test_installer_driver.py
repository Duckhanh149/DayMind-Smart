"""The installer gate must reject lost rows/assets and empty acceptance fixtures."""
from pathlib import Path
import sqlite3
import tempfile
import unittest
import windows_install_upgrade as gate


class InstallerGuards(unittest.TestCase):
    def test_changed_task_or_original_asset_fails_preservation_check(self):
        with tempfile.TemporaryDirectory() as folder:
            support = Path(folder)
            connection = sqlite3.connect(support / "daymind.sqlite")
            connection.execute("CREATE TABLE tasks(id TEXT PRIMARY KEY,title TEXT)")
            connection.execute("INSERT INTO tasks VALUES('fixture','synthetic-private-content')")
            connection.commit(); connection.close()
            library = support / "characters"; library.mkdir()
            source = library / "fixture.png"; source.write_bytes(b"synthetic-image-fixture")
            before = gate.snapshot(support)
            gate.same(before, gate.snapshot(support))
            source.write_bytes(b"changed-synthetic-fixture")
            with self.assertRaises(AssertionError):
                gate.same(before, gate.snapshot(support))
            source.write_bytes(b"synthetic-image-fixture")
            connection = sqlite3.connect(support / "daymind.sqlite")
            connection.execute("UPDATE tasks SET title='changed'")
            connection.commit(); connection.close()
            with self.assertRaises(AssertionError):
                gate.same(before, gate.snapshot(support))

    def test_empty_fixtures_cannot_count_as_a_successful_upgrade(self):
        with tempfile.TemporaryDirectory() as folder:
            support = Path(folder)
            connection = sqlite3.connect(support / "daymind.sqlite")
            connection.execute("CREATE TABLE tasks(id TEXT PRIMARY KEY,title TEXT)")
            connection.commit(); connection.close()
            (support / "characters").mkdir()
            with self.assertRaises(AssertionError):
                gate.snapshot(support)


if __name__ == "__main__":
    unittest.main()
