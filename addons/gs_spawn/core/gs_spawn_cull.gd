class_name GSSpawnCull
extends RefCounted

## Turns watch verdicts into one decision per mover; the host moves, kills or despawns.

const CHANNEL := "spawn"

var rules: GSSpawnCullRules = GSSpawnCullRules.new()
## (position: Vector3, id) -> bool, whether a player can see it. Unset means never seen.
var seen_fn: Callable = Callable()
## Optional appliers for apply(): each takes (id, verdict).
var nudge_fn: Callable = Callable()
var teleport_fn: Callable = Callable()
var despawn_fn: Callable = Callable()
var kill_fn: Callable = Callable()

var counts: Dictionary = {}
var by_category: Dictionary = {}

var _state: Dictionary = {}


func _init(p_rules: GSSpawnCullRules = null) -> void:
	if p_rules != null:
		rules = p_rules


## One decision for one verdict (IGNORE with a reason when nothing is due).
func decide(v: GSSpawnVerdict) -> GSSpawnDecision:
	var d := GSSpawnDecision.new()
	d.id = v.id
	d.verdict = v

	if not rules.enabled:
		d.reason = "disabled"
		return d

	if rules.exempt_kinds.has(String(v.kind)):
		d.reason = "exempt"
		return d

	var action := rules.action_for(v.category)

	if action == GSSpawnDecision.Action.IGNORE:
		d.reason = "ignored by rule"
		return d

	if v.seconds < rules.after_for(v.category):
		d.reason = "not yet"
		return d

	var st: Dictionary = _state.get(v.id, {"last": -1e9, "nudges": 0})

	if v.time - float(st["last"]) < rules.cooldown_sec:
		d.reason = "cooldown"
		return d

	if v.category != GSSpawnVerdict.Category.FELL_OUT and rules.refuse_while_seen \
			and (action == GSSpawnDecision.Action.DESPAWN or action == GSSpawnDecision.Action.TELEPORT) \
			and seen_fn.is_valid() and bool(seen_fn.call(v.position, v.id)):
		d.reason = "seen"
		return d

	if v.time - float(st["last"]) > rules.nudge_reset_sec:
		st["nudges"] = 0

	if v.category == GSSpawnVerdict.Category.STUCK and int(st["nudges"]) < rules.stuck_nudges:
		action = GSSpawnDecision.Action.NUDGE
		st["nudges"] = int(st["nudges"]) + 1

	st["last"] = v.time
	_state[v.id] = st
	d.action = action
	counts[action] = int(counts.get(action, 0)) + 1
	by_category[v.category] = int(by_category.get(v.category, 0)) + 1
	GSLog.debug(CHANNEL, "cull decision", {"mover": str(v.id), "verdict": GSSpawnVerdict.category_name(v.category),
		"action": GSSpawnDecision.action_name(action), "at": str(v.position.snappedf(0.1))})
	return d


## Decisions for a batch of verdicts: at most one per mover, its worst verdict, IGNOREs left out.
func process(verdicts: Array[GSSpawnVerdict]) -> Array[GSSpawnDecision]:
	var worst: Dictionary = {}

	for v in verdicts:
		var held: GSSpawnVerdict = worst.get(v.id)

		if held == null or v.category < held.category:
			worst[v.id] = v

	var out: Array[GSSpawnDecision] = []

	for id in worst:
		var d := decide(worst[id])

		if d.action != GSSpawnDecision.Action.IGNORE:
			out.append(d)

	return out


## Hand decisions to the applier callables; returns how many were applied.
func apply(decisions: Array[GSSpawnDecision]) -> int:
	var n := 0

	for d in decisions:
		var fn: Callable
		match d.action:
			GSSpawnDecision.Action.NUDGE: fn = nudge_fn
			GSSpawnDecision.Action.TELEPORT: fn = teleport_fn
			GSSpawnDecision.Action.DESPAWN: fn = despawn_fn
			GSSpawnDecision.Action.KILL: fn = kill_fn

		if fn.is_valid():
			fn.call(d.id, d.verdict)
			n += 1

		if d.action == GSSpawnDecision.Action.DESPAWN or d.action == GSSpawnDecision.Action.KILL:
			forget(d.id)

	return n


## Drop a mover's nudge and cooldown state once it has left the world.
func forget(id: Variant) -> void:
	_state.erase(id)


func describe() -> String:
	var parts: PackedStringArray = []

	for a in counts:
		parts.append("%s %d" % [GSSpawnDecision.action_name(a), counts[a]])

	return "GSSpawnCull(%s, %d tracked%s)" % ["on" if rules.enabled else "off", _state.size(), ", " + ", ".join(parts) if not parts.is_empty() else ""]


func describe_lines() -> PackedStringArray:
	var lines := PackedStringArray([describe()])

	for c in by_category:
		lines.append("  %s: %d" % [GSSpawnVerdict.category_name(c), by_category[c]])

	return lines
