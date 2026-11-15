extends SceneTree
## License keys: a genuine key verifies offline, and a tampered, forged, expired, malformed or unsigned key
## does not. Fixtures are made by tools/license_tool.py with a TEST-ONLY key pair.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	var f := FileAccess.open("res://tests/fixtures/license_fixtures.json", FileAccess.READ)
	var fx: Dictionary = JSON.parse_string(f.get_as_text())
	var pub: String = fx["public_pem"]
	var good := LicenseKey.verify(fx["good"], pub)
	_check("a genuine full key verifies (%s)" % good["reason"], good["ok"] and good["payload"]["ed"] == "full")
	var tester := LicenseKey.verify(fx["tester"], pub)
	_check("a genuine tester key verifies and carries an expiry", tester["ok"] and int(tester["payload"]["exp"]) > 0)
	var expired := LicenseKey.verify(fx["expired"], pub)
	_check("(control) an expired tester key is refused as expired", not expired["ok"] and expired["reason"] == "expired")
	_check("an expired key verifies when 'now' is moved back", LicenseKey.verify(fx["expired"], pub, int(Time.get_unix_time_from_system()) - 1000)["ok"])
	var tampered := LicenseKey.verify(fx["tampered"], pub)
	_check("(control) a key whose payload was edited (full -> press) is refused", not tampered["ok"] and tampered["reason"] == "signature")
	var forged := LicenseKey.verify(fx["good"], fx["other_public_pem"])
	_check("(control) a key checked against someone else's public key is refused", not forged["ok"] and forged["reason"] == "signature")
	for junk in ["", "hello", "PA1.a.b.c", "PA2.abc.def", "PA1..", "PA1.!!!.???"]:
		var r := LicenseKey.verify(junk, pub)
		_check("(control) junk '%s' is refused (%s)" % [junk, r["reason"]], not r["ok"])
	_check("whitespace around a good key is forgiven", LicenseKey.verify("  " + String(fx["good"]) + "\n", pub)["ok"])
	_check("with no public key available the check refuses instead of passing", LicenseKey.verify(fx["good"])["reason"] == "no_key")      # no public key shipped in this project yet
	print("[test_license] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
