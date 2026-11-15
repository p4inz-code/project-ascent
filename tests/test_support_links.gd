extends SceneTree
## The game is free: the About page offers exactly two donation links (Buy Me a Coffee and the UPI page)
## and no purchase, key or paywall code runs anywhere in the game flow.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	_check("the coffee link points at buymeacoffee.com/p4inz", AboutPage.SUPPORT_BMC == "https://buymeacoffee.com/p4inz")
	_check("the UPI link points at the donation page", AboutPage.SUPPORT_UPI == "https://p4inz-code.github.io/donate/")
	_check("(control) both are https and on the owner's own pages", AboutPage.SUPPORT_BMC.begins_with("https://") and AboutPage.SUPPORT_UPI.begins_with("https://p4inz-code.github.io/"))
	await physics_frame
	var page := AboutPage.new()
	root.add_child(page)
	for i in 3:
		await process_frame
	_check("the About page has the coffee button", page.find_child("SupportBmc", true, false) != null)
	_check("the About page has the UPI button", page.find_child("SupportUpi", true, false) != null)
	_check("it says the game is free", _any_text(page, "FREE, FOREVER"))
	page.queue_free()
	# nothing in the game flow checks a purchase: the licence verifier is not referenced outside its own files and tests
	var refs := 0
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd") and f != "license_key.gd":
			var text := FileAccess.get_file_as_string("res://scripts/" + f)
			if text.contains("LicenseKey"):
				refs += 1
	_check("(no paywall) no gameplay script calls the licence verifier (%d do)" % refs, refs == 0)
	print("[test_support_links] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _any_text(n: Node, needle: String) -> bool:
	if n is Label and (n as Label).text.contains(needle):
		return true
	for c in n.get_children():
		if _any_text(c, needle):
			return true
	return false
