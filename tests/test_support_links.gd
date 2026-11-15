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
	var contribute: Button = page.find_child("Contribute", true, false)
	_check("the About page has a CONTRIBUTE TO DEVELOPMENT button with the heart", contribute != null and contribute.icon != null)
	contribute.pressed.emit()
	for i in 3:
		await process_frame
	var sp: Node = null
	for c in page.get_children():
		if c is SupportPage:
			sp = c
	_check("it opens the support page with the coffee and UPI buttons", sp != null and sp.find_child("SupportBmc", true, false) != null and sp.find_child("SupportUpi", true, false) != null)
	_check("(control) the heart is a real picture, 11 x 10 cells", PixelHeart.texture(1).get_width() == 11 and PixelHeart.texture(1).get_height() == 10)
	_check("it says the game is free", _any_text(page, "FREE, FOREVER"))
	page.queue_free()
	var menu := StartMenu.new()
	root.add_child(menu)
	for i in 4:
		await process_frame
	var main_btn: Button = menu.find_child("Contribute", true, false)
	_check("the main page has the heart CONTRIBUTE TO DEVELOPMENT button", main_btn != null and main_btn.icon != null and main_btn.text.contains("CONTRIBUTE"))
	menu.queue_free()
	var ending := EndingScreen.new()
	ending.total = 100
	ending.goal = 100
	root.add_child(ending)
	for i in 3:
		await process_frame
	_check("the ending screen offers the coffee button too", ending.find_child("SupportCoffee", true, false) != null)
	ending.queue_free()
	# no paywall and no key system: there is no player key code anywhere in the game
	var refs := 0
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			var text := FileAccess.get_file_as_string("res://scripts/" + f)
			if text.contains("LicenseKey") or text.contains("activation_key") or text.contains("is_licensed"):
				refs += 1
	_check("(no paywall, no key system) no script handles player keys (%d do)" % refs, refs == 0 and not FileAccess.file_exists("res://scripts/license_key.gd"))
	print("[test_support_links] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _any_text(n: Node, needle: String) -> bool:
	if n is Label and (n as Label).text.contains(needle):
		return true
	for c in n.get_children():
		if _any_text(c, needle):
			return true
	return false
