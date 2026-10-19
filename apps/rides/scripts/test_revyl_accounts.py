import contextlib
import io
import json
from pathlib import Path
import runpy
import tempfile
import time
import unittest
from unittest.mock import patch

import revyl_accounts as accounts


def session(role, name="Account fixture"):
    profile = {"id": role + "-id", "name": name, "email": role + "@rides.invalid", "role": role, "vehicle": None, "plate": None}
    return {"account": profile, "roomCode": profile["id"], "participantId": profile["id"], "name": name, "role": role, "token": "user." + "x" * 43, "expiresAt": (time.time() + 3600) * 1000}


class AccountSetupTests(unittest.TestCase):
    def response(self, request, timeout):
        value = json.loads(request.data)
        return io.BytesIO(json.dumps({"status": "success", "value": session(value["args"]["role"], value["args"]["name"])}).encode())

    def test_registration_uses_public_account_action_and_fresh_credentials(self):
        with patch.object(accounts, "urlopen", side_effect=self.response) as request:
            accounts.register("rider", "test-area")
            accounts.register("rider", "test-area")
        values = [json.loads(call.args[0].data) for call in request.call_args_list]
        self.assertEqual({value["path"] for value in values}, {"accounts:signUp"})
        self.assertEqual({value["args"]["serviceArea"] for value in values}, {"test-area"})
        self.assertNotEqual(values[0]["args"]["email"], values[1]["args"]["email"])
        self.assertNotEqual(values[0]["args"]["password"], values[1]["args"]["password"])
        self.assertGreaterEqual(len(values[0]["args"]["password"]), 32)
        for call in request.call_args_list:
            self.assertEqual(call.args[0].full_url, accounts.BACKEND_URL + "/api/action")
            self.assertNotIn("Authorization", call.args[0].headers)

    def test_driver_registration_contains_vehicle_details(self):
        with patch.object(accounts, "urlopen", side_effect=self.response) as request:
            accounts.register("driver", "test-area")
        value = json.loads(request.call_args.args[0].data)["args"]
        self.assertEqual(value["role"], "driver")
        self.assertTrue(value["vehicle"])
        self.assertTrue(value["plate"])

    def test_registration_errors_do_not_expose_request_or_response(self):
        for result in [OSError("private-credential"), io.BytesIO(b'{"status":"error","errorMessage":"private-credential"}')]:
            with patch.object(accounts, "urlopen", side_effect=result if isinstance(result, Exception) else None, return_value=result):
                with self.assertRaises(RuntimeError) as error:
                    accounts.register("rider", "test-area")
            self.assertNotIn("private-credential", str(error.exception))

    def test_session_validation_rejects_role_identity_and_expiry_mismatches(self):
        for update in [{"role": "driver"}, {"participantId": "other-user"}, {"roomCode": "invitation"}, {"token": "legacy-token"}, {"expiresAt": 0}]:
            value = session("rider")
            value.update(update)
            with self.assertRaises(ValueError):
                accounts.validate_session(value, "rider")

    def test_pair_file_registers_distinct_users_in_same_isolated_area_and_reuses_them(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(accounts, "urlopen", side_effect=self.response) as request:
            path = Path(folder) / "private-pair.json"
            rider = accounts.account_for("rider", path)
            driver = accounts.account_for("driver", path)
            payload = json.loads(path.read_text())
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertNotEqual(rider["account"]["id"], driver["account"]["id"])
            self.assertEqual(request.call_count, 2)
            values = [json.loads(call.args[0].data)["args"] for call in request.call_args_list]
            self.assertEqual(values[0]["serviceArea"], values[1]["serviceArea"])
            self.assertTrue(payload["serviceArea"].startswith("test-"))
            self.assertEqual(payload["backend"], accounts.BACKEND_URL)
            self.assertNotIn("password", path.read_text())

    def test_independent_sessions_register_independent_areas(self):
        with patch.object(accounts, "urlopen", side_effect=self.response) as request:
            accounts.account_for("rider")
            accounts.account_for("rider")
        areas = [json.loads(call.args[0].data)["args"]["serviceArea"] for call in request.call_args_list]
        self.assertNotEqual(*areas)

    def test_refuses_public_or_symlinked_account_files(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "pair.json"
            path.write_text(json.dumps({"backend": accounts.BACKEND_URL, "rider": session("rider")}))
            path.chmod(0o644)
            with self.assertRaises(RuntimeError):
                accounts.account_for("rider", path)
            path.chmod(0o600)
            link = Path(folder) / "link.json"
            link.symlink_to(path)
            with self.assertRaises(RuntimeError):
                accounts.account_for("rider", link)

    def test_hook_failure_prints_no_partial_launch_values(self):
        output, errors = io.StringIO(), io.StringIO()
        script = Path(__file__).with_name("prepare-revyl-session.py")
        with patch.object(accounts, "account_for", side_effect=RuntimeError("private-credential")), contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors), self.assertRaises(SystemExit) as exit:
            runpy.run_path(str(script), run_name="__main__")
        self.assertEqual(exit.exception.code, 1)
        self.assertEqual(output.getvalue(), "")
        self.assertNotIn("private-credential", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
