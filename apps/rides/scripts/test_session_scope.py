import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import unittest
from unittest.mock import patch

import revyl_accounts


class SessionAccountScopeTests(unittest.TestCase):
    def test_both_roles_keep_the_selected_revyl_account_when_another_key_exists(self):
        script = Path(__file__).with_name("start-session.py")
        response = subprocess.CompletedProcess([], 0, stdout=json.dumps({"session_id": "fixture-session"}), stderr="")
        for role in ("rider", "driver"):
            with self.subTest(role=role):
                with patch.dict(os.environ, {"REVYL_API_KEY": "benchmarks-fixture", "REVYL_UBER_API_KEY": "uber-fixture"}), patch.object(sys, "argv", [str(script), "--role", role]), patch.object(revyl_accounts, "account_for", return_value={"token": "user." + "x" * 43}), patch("subprocess.run", return_value=response) as run, contextlib.redirect_stdout(io.StringIO()):
                    runpy.run_path(str(script), run_name="__main__")
                self.assertEqual(run.call_args.kwargs["env"]["REVYL_API_KEY"], "benchmarks-fixture")


if __name__ == "__main__":
    unittest.main()
