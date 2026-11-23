extends "res://examples/selftest/node_tests.gd"

## Spawns are shared by default; `one_per_spawn` opts into one occupant per site.


func _test_shared_spawns() -> void:
	_section("shared spawns by default")

	var rules := GSSpawnRules.deathmatch()
	_check(not rules.one_per_spawn, "sharing is the default: one_per_spawn is off")
	var d := _director(rules)
	var sites := _grid(19)
	var failures := 0
	var fell := 0

	for i in 40:
		var res := d.choose_from(sites, GSSpawnRequest.make("p%d" % i, &"", &"", i))
		if not res.ok:
			failures += 1
			continue

		var site: GSSpawnSite = (res.value as GSSpawnChoice).site
		fell += 1 if (res.value as GSSpawnChoice).fell_back else 0
		d.set_occupancy(site.id, site.occupants + 1)
		for s in sites:
			if s.id == site.id:
				s.occupants += 1

	_check(failures == 0, "19 sites, 40 players: every one spawns")
	_check(fell == 0, "and sharing is never a fallback or a warning")
	d.queue_free()

	# Strict mode: a hard veto, then the fallback decides.
	var strict := GSSpawnRules.deathmatch()
	strict.one_per_spawn = true
	var ds := _director(strict)
	var pool := _grid(19)
	var used := {}
	var strict_fell := 0

	for i in 40:
		var res := ds.choose_from(pool, GSSpawnRequest.make("s%d" % i, &"", &"", i))
		var choice: GSSpawnChoice = res.value
		strict_fell += 1 if choice.fell_back else 0
		used[choice.site.id] = true
		choice.site.occupants += 1

	_check(used.size() == 19, "strict: the first 19 players take 19 different sites")
	_check(strict_fell == 21, "strict with fallback on: the 20th and later share, flagged fell_back")

	strict.fall_back_when_nothing_passes = false
	var refused := ds.choose_from(pool, GSSpawnRequest.make("late", &"", &"", 99))
	_check(not refused.ok, "strict with fallback off: the 20th is refused, the caller waits")
	ds.queue_free()
