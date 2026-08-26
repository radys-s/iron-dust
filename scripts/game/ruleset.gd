class_name Ruleset
extends RefCounted

## Pravidla jedne partie. Do Faze 6 byl vesken balanc `const` v GameData,
## takze nesel nastavit per hru — obtiznost by se bez tohohle nedala udelat.
##
## Slovnik je ZAMERNE plne vyplneny, ne fallback na konstanty. Fallback svadi
## k tomu, ze se na novy klic zapomene a hra tise bezi na vychozi hodnote;
## chybejici klic tady spadne hlasite. GameData drzi vychozi hodnoty, ze
## kterych se rezimy skladaji, takze je porad jedno misto pravdy pro balanc.
##
## Konzumenti (Combat, EnemyAI, TileAction, GameState) prechazeji na
## `gs.ruleset[...]` postupne v Etape 4; do te doby se rezim jen uklada
## a nese se pres save.

const BEGINNER := "beginner"
const ADVANCED := "advanced"

const MODES: Array[String] = [BEGINNER, ADVANCED]

const MODE_NAMES := {
	BEGINNER: "Začátečník",
	ADVANCED: "Pokročilý",
}


static func is_valid(mode: String) -> bool:
	return MODES.has(mode)


static func mode_name(mode: String) -> String:
	return String(MODE_NAMES.get(mode, mode))


## Plne vyplnena pravidla pro rezim. Neznamy rezim spadne na ADVANCED —
## poskozeny save nesmi hraci tise zapnout lehci obtiznost.
static func for_mode(mode: String) -> Dictionary:
	var rules := _base()
	if mode == BEGINNER:
		_apply_beginner(rules)
	return rules


## Spolecny zaklad = dnesni chovani hry (odpovida rezimu Pokrocily).
static func _base() -> Dictionary:
	return {
		"mode": ADVANCED,

		# --- Harlan-Voss ---
		# Muze korporace dobyt Dustfall a tim hru ukoncit prohrou?
		"ai_can_capture_town": true,
		# Prizpusobuje se AI stylu hrace? (Etapa 4)
		"ai_adaptive": true,
		# Muze AI nicit polozene koleje? (Etapa 3)
		"ai_can_sabotage_rails": true,
		"ai_attack_cost_gold": GameData.AI_ATTACK_COST_GOLD,
		"ai_min_attack_advantage": GameData.AI_MIN_ATTACK_ADVANTAGE,
		"ai_base_income_gold": GameData.AI_BASE_INCOME_GOLD,
		"ai_actions_max": GameData.AI_ACTIONS_MAX,

		# --- Ekonomika (Etapa 3) ---
		# Vyzaduje stavba naradi? Tohle je hlavni "hard to master" brzda.
		"build_requires_tools": true,
		# Vynasi i nevlastnena puda? Dedictvi prototypu, v obou rezimech pryc.
		"unowned_land_yields": false,

		# --- Cil ---
		# Kolik tahu je na dostavbu zeleznice. 0 = bez limitu.
		"turn_limit": 120,
	}


static func _apply_beginner(rules: Dictionary) -> void:
	# Zadani: v Beginner te Voss nemuze znicit, prohrajes jen nesplnenim cile
	# v case. Proto zustava agresivni a muze brat uzemi — jen na Dustfall
	# nesmi, takze hra ma porad tah, ale ne slepou ulicku.
	rules["mode"] = BEGINNER
	rules["ai_can_capture_town"] = false
	rules["ai_adaptive"] = false
	rules["ai_can_sabotage_rails"] = false
	rules["build_requires_tools"] = false

	# Mirnejsi korporace: draz utoci a pusti se jen do jasne vyhranych soubojů.
	rules["ai_attack_cost_gold"] = int(GameData.AI_ATTACK_COST_GOLD * 1.6)
	rules["ai_min_attack_advantage"] = 4
	rules["ai_base_income_gold"] = int(GameData.AI_BASE_INCOME_GOLD * 0.7)
	rules["ai_actions_max"] = 2

	# Velkorysejsi limit — zacatecnik se ma stihnout naucit reteze, ne zavodit.
	rules["turn_limit"] = 180
