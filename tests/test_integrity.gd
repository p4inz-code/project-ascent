extends SceneTree
## Release authenticity: a signed manifest with matching files is ok; a changed file, a changed manifest,
## a wrong key, a missing file and an unsigned (dev) folder are each told apart. Fixtures are made by
## tools/license_tool.py make-manifest with a TEST-ONLY key.

var _failures: int = 0
const SRC := "res://tests/fixtures/integrity/good"
const WORK := "user://integrity_test"


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _make(name: String, with_manifest: bool = true) -> String:
	var d := WORK.path_join(name)
	DirAccess.make_dir_recursive_absolute(d)
	for f in ["a.bin", "b.bin"] + (["manifest.json", "manifest.json.sig"] if with_manifest else []):
		var data := FileAccess.get_file_as_bytes(SRC.path_join(f))
		var o := FileAccess.open(d.path_join(f), FileAccess.WRITE)
		o.store_buffer(data)
		o.close()
	return d


func _write(path: String, text: String) -> void:
	var o := FileAccess.open(path, FileAccess.WRITE)
	o.store_string(text)
	o.close()


func _run() -> void:
	var pub: String = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/integrity/public.json"))["public_pem"]
	var ok_dir := _make("ok")
	var r := Integrity.check(ok_dir, pub)
	_check("an untouched signed release is ok (version %s)" % r["version"], r["state"] == "ok" and r["version"] == "9.9.9")
	var mod := _make("modified")
	_write(mod.path_join("b.bin"), "patched by someone")
	var rm := Integrity.check(mod, pub)
	_check("(control) a changed file is reported as modified, naming it %s" % str(rm["bad"]), rm["state"] == "modified" and rm["bad"] == ["b.bin"])
	var gone := _make("gone")
	DirAccess.remove_absolute(gone.path_join("a.bin"))
	_check("(control) a deleted file is reported as modified", Integrity.check(gone, pub)["state"] == "modified")
	var edited := _make("edited")
	_write(edited.path_join("manifest.json"), FileAccess.get_file_as_string(edited.path_join("manifest.json")).replace("9.9.9", "1.0.0"))
	_check("(control) an edited manifest fails its signature", Integrity.check(edited, pub)["state"] == "bad_signature")
	var other := Crypto.new().generate_rsa(2048).save_to_string(true)
	_check("(control) the manifest checked against another public key fails", Integrity.check(ok_dir, other)["state"] == "bad_signature")
	var dev := _make("dev", false)
	_check("a folder with no manifest (a dev build) is unsigned and raises no notice", Integrity.check(dev, pub)["state"] == "unsigned" and Integrity.notice_text(Integrity.check(dev, pub)) == "")
	_check("the editor run (no release folder) is unsigned", Integrity.check("")["state"] == "unsigned")
	_check("a modified release shows the notice naming the official page", Integrity.notice_text(rm).contains("GITHUB.COM/P4INZ-CODE/PROJECT-ASCENT"))
	_check("an ok release shows no notice", Integrity.notice_text(r) == "")
	print("[test_integrity] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
