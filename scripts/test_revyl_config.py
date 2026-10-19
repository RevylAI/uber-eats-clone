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
from urllib.parse import parse_qs, urlparse

import yaml


ROOT = Path(__file__).resolve().parents[1]


class RevylConfigTests(unittest.TestCase):
    def setUp(self):
        self.projects = [ROOT, ROOT / "apps/rides"]
        self.configs = [yaml.safe_load((root / ".revyl/config.yaml").read_text()) for root in self.projects]

    def test_projects_and_apps_are_distinct(self):
        self.assertNotEqual(self.configs[0]["project"]["id"], self.configs[1]["project"]["id"])
        apps = []
        for config in self.configs:
            profiles = config["build"]["profiles"]
            self.assertEqual(len(profiles), 1)
            recipe = profiles[config["pr_review"]["build"]["profile"]]["ios"]
            apps.append(recipe["app_id"])
        self.assertNotEqual(*apps)

    def test_build_paths_are_project_relative(self):
        for root, config, bundle in zip(self.projects, self.configs, ["EatsClone.app", "RidesDemo.app"]):
            recipe = next(iter(config["build"]["profiles"].values()))["ios"]
            self.assertEqual(recipe["build_commands"], ["bash scripts/build-ios.sh"])
            self.assertTrue((root / "scripts/build-ios.sh").is_file())
            self.assertEqual(recipe["output_path"], "build/Build/Products/Debug-iphonesimulator/" + bundle)

    def test_session_hooks_are_isolated_and_mint_fresh_tokens(self):
        for root, config, prefix, scheme, role in zip(self.projects, self.configs, ["EATSCLONE", "RIDES"], ["eatsclone", "ridesdemo"], ["buyer", "rider"]):
            session = config["session"]
            hook = root / session["before_script"]["script_path"]
            self.assertTrue(os.access(hook, os.X_OK))
            values = []
            for _ in range(2):
                result = subprocess.run([sys.executable, str(hook)], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0)
                value = dict(line.split("=", 1) for line in result.stdout.splitlines())
                self.assertEqual(set(value), {prefix + "_AUTH_BYPASS_ENABLED", prefix + "_AUTH_BYPASS_TOKEN"})
                self.assertEqual(value[prefix + "_AUTH_BYPASS_ENABLED"], "true")
                self.assertTrue(len(value[prefix + "_AUTH_BYPASS_TOKEN"]) >= 32)
                values.append(value)
            self.assertTrue(values[0] != values[1], "Session hooks must mint a fresh token")
            auth = session["auth_bypass"]
            self.assertEqual(set(auth["launch_vars"]), set(values[0]))
            link = urlparse(auth["deep_link"])
            self.assertEqual(link.scheme, scheme)
            self.assertEqual(link.netloc, "revyl-auth")
            self.assertEqual(parse_qs(link.query), {"token": ["${" + prefix + "_AUTH_BYPASS_TOKEN}"], "role": [role], "redirect": ["/home"]})

    def test_review_policies_select_their_own_app(self):
        for config in self.configs:
            review = config["pr_review"]
            self.assertTrue(review["enabled"])
            self.assertTrue(review["proof_of_changes"]["enabled"])
            self.assertEqual(review["proof_of_changes"]["harness"]["kind"], "revyl")
            self.assertTrue(review["strict_ci_check"]["build"])
            self.assertTrue(review["review_triggers"]["paths"])
        self.assertNotIn("apps/rides/**", self.configs[0]["pr_review"]["review_triggers"]["paths"])
        self.assertIn("services/ride-demo/**", self.configs[1]["pr_review"]["review_triggers"]["paths"])
        self.assertNotIn("EatsClone/**", self.configs[1]["pr_review"]["review_triggers"]["paths"])

    def test_rides_launcher_uses_nested_project_for_both_roles(self):
        script = ROOT / "apps/rides/scripts/start-session.py"
        for role in ["rider", "driver"]:
            output = io.StringIO()
            response = subprocess.CompletedProcess([], 0, stdout=json.dumps({"session_id": "test-session", "launch_env": "must-not-be-printed"}), stderr="")
            with patch.object(sys, "argv", [str(script), "--role", role]), patch("subprocess.run", return_value=response) as run, contextlib.redirect_stdout(output):
                runpy.run_path(str(script), run_name="__main__")
            self.assertEqual(run.call_args.kwargs["cwd"], ROOT / "apps/rides")
            command = run.call_args.args[0]
            link = command[command.index("--app-link") + 1]
            self.assertTrue(urlparse(link).scheme == "ridesdemo")
            self.assertTrue(parse_qs(urlparse(link).query)["role"] == [role])
            app = next(iter(self.configs[1]["build"]["profiles"].values()))["ios"]["app_id"]
            self.assertTrue(command[command.index("--app-id") + 1] == app)
            self.assertEqual(json.loads(output.getvalue()), {"session_id": "test-session", "role": role})

    def test_runtime_state_is_ignored_for_both_projects(self):
        for root in self.projects:
            path = root / ".revyl/before-session-values.json"
            result = subprocess.run(["git", "check-ignore", "-q", str(path)], cwd=ROOT)
            self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
