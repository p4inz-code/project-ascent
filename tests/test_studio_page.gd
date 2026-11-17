extends SceneTree
## MORE FROM P4INZ (round 3): the title badge opens an in-game page whose cards come from data/studio_projects.json.

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(label: String, ok: bool) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok:
		_failures += 1


func _run() -> void:
	var projects := StudioPage.load_projects()
	_check("the projects file loads (%d projects)" % projects.size(), projects.size() >= 1)
	var page := StudioPage.new()
	root.add_child(page)
	for i in 4:
		await process_frame
	var cards := 0
	for n in page.find_children("Project_*", "Button", true, false):
		cards += 1
	_check("one card per project (%d cards)" % cards, cards == projects.size())
	_check("(control) the page has a BACK button", page.find_child("Back", true, false) != null)
	page.queue_free()
	var menu := StartMenu.new()
	root.add_child(menu)
	for i in 4:
		await process_frame
	menu._on_studio()
	await process_frame
	var opened := false
	for c in menu.get_children():
		if c is StudioPage:
			opened = true
	_check("the MORE badge opens the in-game page, not a browser", opened)
	print("[test_studio_page] failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)
