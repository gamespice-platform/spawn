class_name GSSpawnPointSet
extends RefCounted

## The authored points of one map, versioned for saving.
##
## The map's own spawns are never edited: `apply_to` patches a map point by id (the def replaces it, so authored settings win), `enabled = false` switches one off, and an id the map lacks is added. An empty set leaves exactly what the map shipped.

var points: Array[GSSpawnPointDef] = []


func add(p: GSSpawnPointDef) -> void:
	points.append(p)


func find(id: StringName) -> GSSpawnPointDef:
	for p in points:
		if p.id == id:
			return p

	return null


func to_dict() -> Dictionary:
	var list: Array = []

	for p in points:
		list.append(p.to_dict())

	return {"version": GSSpawnPointDef.VERSION, "points": list}


## Refuses a newer version than this build knows; an older or missing one loads with defaults.
static func from_dict(d: Dictionary) -> GSResult:
	var v := int(d.get("version", 1))

	if v > GSSpawnPointDef.VERSION:
		return GSResult.fail(GSError.CODE_VERSION, "spawn point set version %d is newer than %d" % [v, GSSpawnPointDef.VERSION])

	var raw: Variant = d.get("points", [])

	if not (raw is Array):
		return GSResult.fail(GSError.CODE_INVALID, "points must be a list")

	var set := GSSpawnPointSet.new()
	var seen := {}

	for e: Variant in raw:
		if not (e is Dictionary):
			return GSResult.fail(GSError.CODE_INVALID, "a point must be a dictionary")

		var p := GSSpawnPointDef.from_dict(e)
		var bad := p.problem()

		if bad != "":
			return GSResult.fail(GSError.CODE_INVALID, "point '%s': %s" % [p.id, bad])

		if seen.has(p.id):
			return GSResult.fail(GSError.CODE_CONFLICT, "two points share the id '%s'" % p.id)

		seen[p.id] = true
		set.points.append(p)

	return GSResult.success(set)


## Applies the set to [param sites] (the map's own, left untouched as objects): a def with a map id replaces that site, any other is appended. Returns how many took effect.
func apply_to(sites: Array[GSSpawnSite], tick_rate: int = 64) -> int:
	var applied := 0

	for p in points:
		var s := p.to_site(tick_rate)
		var at := -1

		for i in sites.size():
			if sites[i].id == p.id:
				at = i
				break

		if at >= 0:
			sites[at] = s
		else:
			sites.append(s)

		applied += 1

	return applied
