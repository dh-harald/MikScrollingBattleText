-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Parser Tables
--
-- Declarative description of every 1.12.1 combat log global string the parser
-- understands. Each entry names the global string and maps its format
-- arguments, IN THE ORDER OF THE enUS STRING, to parser event fields. The
-- parser reads the client's own localized string at runtime, so this works on
-- every client language; localized strings that reorder arguments ("%2$s")
-- are handled by the capture reordering in Parser.lua.
--
-- Entry fields:
--   [1]  parser event type
--   [2]  who is the player: "S" = source, "R" = recipient, "SR" = both, "" = neither
--   [3]  argument fields, space separated, in enUS argument order ("-" = ignored)
--   rest: constant fields copied into the event
--
-- Argument field names with special handling in Parser.lua:
--   damageTypeName -> damageType (school bit), powerTypeName -> powerType,
--   extraPowerTypeName -> extraPowerType, amount/extraAmount/amountStacks -> numbers.
-------------------------------------------------------------------------------

local T = {}
MikSBT.ParserTables = T

-- The 1.12 text for every string is noted next to it (enUS GlobalStrings).
T.combat = {
	-- Melee hits.
	COMBATHITSELFOTHER = { "damage", "S", "recipientName amount" }, -- You hit %s for %d.
	COMBATHITCRITSELFOTHER = { "damage", "S", "recipientName amount", isCrit = true }, -- You crit %s for %d.
	COMBATHITSCHOOLSELFOTHER = { "damage", "S", "recipientName amount damageTypeName" }, -- You hit %s for %d %s damage.
	COMBATHITCRITSCHOOLSELFOTHER = { "damage", "S", "recipientName amount damageTypeName", isCrit = true },
	COMBATHITOTHERSELF = { "damage", "R", "sourceName amount" }, -- %s hits you for %d.
	COMBATHITCRITOTHERSELF = { "damage", "R", "sourceName amount", isCrit = true },
	COMBATHITSCHOOLOTHERSELF = { "damage", "R", "sourceName amount damageTypeName" },
	COMBATHITCRITSCHOOLOTHERSELF = { "damage", "R", "sourceName amount damageTypeName", isCrit = true },
	COMBATHITOTHEROTHER = { "damage", "", "sourceName recipientName amount" }, -- %s hits %s for %d.
	COMBATHITCRITOTHEROTHER = { "damage", "", "sourceName recipientName amount", isCrit = true },
	COMBATHITSCHOOLOTHEROTHER = { "damage", "", "sourceName recipientName amount damageTypeName" },
	COMBATHITCRITSCHOOLOTHEROTHER = { "damage", "", "sourceName recipientName amount damageTypeName", isCrit = true },

	-- Melee misses.
	MISSEDSELFOTHER = { "miss", "S", "recipientName", missType = "MISS" }, -- You miss %s.
	MISSEDOTHERSELF = { "miss", "R", "sourceName", missType = "MISS" },
	MISSEDOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "MISS" },
	VSDODGESELFOTHER = { "miss", "S", "recipientName", missType = "DODGE" }, -- You attack. %s dodges.
	VSDODGEOTHERSELF = { "miss", "R", "sourceName", missType = "DODGE" },
	VSDODGEOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "DODGE" },
	VSPARRYSELFOTHER = { "miss", "S", "recipientName", missType = "PARRY" },
	VSPARRYOTHERSELF = { "miss", "R", "sourceName", missType = "PARRY" },
	VSPARRYOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "PARRY" },
	VSBLOCKSELFOTHER = { "miss", "S", "recipientName", missType = "BLOCK" },
	VSBLOCKOTHERSELF = { "miss", "R", "sourceName", missType = "BLOCK" },
	VSBLOCKOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "BLOCK" },
	VSDEFLECTSELFOTHER = { "miss", "S", "recipientName", missType = "DEFLECT" },
	VSDEFLECTOTHERSELF = { "miss", "R", "sourceName", missType = "DEFLECT" },
	VSDEFLECTOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "DEFLECT" },
	VSABSORBSELFOTHER = { "miss", "S", "recipientName", missType = "ABSORB" },
	VSABSORBOTHERSELF = { "miss", "R", "sourceName", missType = "ABSORB" },
	VSABSORBOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "ABSORB" },
	VSEVADESELFOTHER = { "miss", "S", "recipientName", missType = "EVADE" },
	VSEVADEOTHERSELF = { "miss", "R", "sourceName", missType = "EVADE" },
	VSEVADEOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "EVADE" },
	VSIMMUNESELFOTHER = { "miss", "S", "recipientName", missType = "IMMUNE" }, -- You attack but %s is immune.
	VSIMMUNEOTHERSELF = { "miss", "R", "sourceName", missType = "IMMUNE" },
	VSIMMUNEOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "IMMUNE" },
	VSRESISTSELFOTHER = { "miss", "S", "recipientName", missType = "RESIST" },
	VSRESISTOTHERSELF = { "miss", "R", "sourceName", missType = "RESIST" },
	VSRESISTOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "RESIST" },
	IMMUNESELFOTHER = { "miss", "S", "recipientName", missType = "IMMUNE" }, -- You hit %s, who is immune.
	IMMUNEOTHERSELF = { "miss", "R", "sourceName", missType = "IMMUNE" },
	IMMUNEOTHEROTHER = { "miss", "", "sourceName recipientName", missType = "IMMUNE" },

	-- Spell hits.
	SPELLLOGSELFOTHER = { "damage", "S", "skillName recipientName amount" }, -- Your %s hits %s for %d.
	SPELLLOGCRITSELFOTHER = { "damage", "S", "skillName recipientName amount", isCrit = true },
	SPELLLOGSCHOOLSELFOTHER = { "damage", "S", "skillName recipientName amount damageTypeName" }, -- Your %s hits %s for %d %s damage.
	SPELLLOGCRITSCHOOLSELFOTHER = { "damage", "S", "skillName recipientName amount damageTypeName", isCrit = true },
	SPELLLOGSELFSELF = { "damage", "SR", "skillName amount" }, -- Your %s hits you for %d.
	SPELLLOGCRITSELFSELF = { "damage", "SR", "skillName amount", isCrit = true },
	SPELLLOGSCHOOLSELFSELF = { "damage", "SR", "skillName amount damageTypeName" },
	SPELLLOGCRITSCHOOLSELFSELF = { "damage", "SR", "skillName amount damageTypeName", isCrit = true },
	SPELLLOGOTHERSELF = { "damage", "R", "sourceName skillName amount" }, -- %s's %s hits you for %d.
	SPELLLOGCRITOTHERSELF = { "damage", "R", "sourceName skillName amount", isCrit = true },
	SPELLLOGSCHOOLOTHERSELF = { "damage", "R", "sourceName skillName amount damageTypeName" },
	SPELLLOGCRITSCHOOLOTHERSELF = { "damage", "R", "sourceName skillName amount damageTypeName", isCrit = true },
	SPELLLOGOTHEROTHER = { "damage", "", "sourceName skillName recipientName amount" }, -- %s's %s hits %s for %d.
	SPELLLOGCRITOTHEROTHER = { "damage", "", "sourceName skillName recipientName amount", isCrit = true },
	SPELLLOGSCHOOLOTHEROTHER = { "damage", "", "sourceName skillName recipientName amount damageTypeName" },
	SPELLLOGCRITSCHOOLOTHEROTHER = { "damage", "", "sourceName skillName recipientName amount damageTypeName", isCrit = true },
	SPELLSPLITDAMAGESELFOTHER = { "damage", "S", "skillName recipientName amount" }, -- Your %s causes %s %d damage.
	SPELLSPLITDAMAGEOTHERSELF = { "damage", "R", "sourceName skillName amount" },
	SPELLSPLITDAMAGEOTHEROTHER = { "damage", "", "sourceName skillName recipientName amount" },

	-- Spell misses. The "%s's %s was dodged." forms name only the caster: the
	-- recipient is the player.
	SPELLMISSSELFOTHER = { "miss", "S", "skillName recipientName", missType = "MISS" }, -- Your %s missed %s.
	SPELLMISSOTHERSELF = { "miss", "R", "sourceName skillName", missType = "MISS" },
	SPELLMISSOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "MISS" },
	SPELLDODGEDSELFOTHER = { "miss", "S", "skillName recipientName", missType = "DODGE" },
	SPELLDODGEDOTHERSELF = { "miss", "R", "sourceName skillName", missType = "DODGE" },
	SPELLDODGEDOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "DODGE" },
	SPELLPARRIEDSELFOTHER = { "miss", "S", "skillName recipientName", missType = "PARRY" },
	SPELLPARRIEDOTHERSELF = { "miss", "R", "sourceName skillName", missType = "PARRY" },
	SPELLPARRIEDOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "PARRY" },
	SPELLBLOCKEDSELFOTHER = { "miss", "S", "skillName recipientName", missType = "BLOCK" },
	SPELLBLOCKEDOTHERSELF = { "miss", "R", "sourceName skillName", missType = "BLOCK" },
	SPELLBLOCKEDOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "BLOCK" },
	SPELLDEFLECTEDSELFOTHER = { "miss", "S", "skillName recipientName", missType = "DEFLECT" },
	SPELLDEFLECTEDOTHERSELF = { "miss", "R", "sourceName skillName", missType = "DEFLECT" },
	SPELLDEFLECTEDOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "DEFLECT" },
	SPELLEVADEDSELFOTHER = { "miss", "S", "skillName recipientName", missType = "EVADE" },
	SPELLEVADEDOTHERSELF = { "miss", "R", "sourceName skillName", missType = "EVADE" },
	SPELLEVADEDOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "EVADE" },
	SPELLRESISTSELFOTHER = { "miss", "S", "skillName recipientName", missType = "RESIST" }, -- Your %s was resisted by %s.
	SPELLRESISTOTHERSELF = { "miss", "R", "sourceName skillName", missType = "RESIST" },
	SPELLRESISTOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "RESIST" },
	SPELLLOGABSORBSELFOTHER = { "miss", "S", "skillName recipientName", missType = "ABSORB" }, -- Your %s is absorbed by %s.
	SPELLLOGABSORBOTHERSELF = { "miss", "R", "sourceName skillName", missType = "ABSORB" }, -- You absorb %s's %s.
	SPELLLOGABSORBOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "ABSORB" },
	SPELLLOGABSORBSELFSELF = { "miss", "SR", "skillName", missType = "ABSORB" },
	SPELLREFLECTSELFOTHER = { "miss", "S", "skillName recipientName", missType = "REFLECT" }, -- Your %s is reflected back by %s.
	SPELLREFLECTOTHERSELF = { "miss", "R", "sourceName skillName", missType = "REFLECT" }, -- You reflect %s's %s.
	SPELLREFLECTOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "REFLECT" },
	SPELLIMMUNESELFOTHER = { "miss", "S", "skillName recipientName", missType = "IMMUNE" }, -- Your %s failed. %s is immune.
	SPELLIMMUNEOTHERSELF = { "miss", "R", "sourceName skillName", missType = "IMMUNE" },
	SPELLIMMUNEOTHEROTHER = { "miss", "", "sourceName skillName recipientName", missType = "IMMUNE" },
	IMMUNESPELLSELFOTHER = { "miss", "S", "recipientName skillName", missType = "IMMUNE" }, -- %s is immune to your %s.
	IMMUNESPELLOTHERSELF = { "miss", "R", "sourceName skillName", missType = "IMMUNE" }, -- You are immune to %s's %s.
	IMMUNESPELLOTHEROTHER = { "miss", "", "recipientName sourceName skillName", missType = "IMMUNE" },
	IMMUNEDAMAGECLASSSELFOTHER = { "miss", "S", "recipientName damageTypeName", missType = "IMMUNE" }, -- %s is immune to your %s damage.
	IMMUNEDAMAGECLASSOTHERSELF = { "miss", "R", "sourceName damageTypeName", missType = "IMMUNE" },
	IMMUNEDAMAGECLASSOTHEROTHER = { "miss", "", "recipientName sourceName damageTypeName", missType = "IMMUNE" },

	-- Periodic damage.
	PERIODICAURADAMAGESELFOTHER = { "damage", "S", "recipientName amount damageTypeName skillName", isDoT = true }, -- %s suffers %d %s damage from your %s.
	PERIODICAURADAMAGEOTHERSELF = { "damage", "R", "amount damageTypeName sourceName skillName", isDoT = true }, -- You suffer %d %s damage from %s's %s.
	PERIODICAURADAMAGESELFSELF = { "damage", "SR", "amount damageTypeName skillName", isDoT = true },
	PERIODICAURADAMAGEOTHEROTHER = { "damage", "", "recipientName amount damageTypeName sourceName skillName", isDoT = true },

	-- Damage shields.
	DAMAGESHIELDSELFOTHER = { "damage", "S", "amount damageTypeName recipientName", isDamageShield = true }, -- You reflect %d %s damage to %s.
	DAMAGESHIELDOTHERSELF = { "damage", "R", "sourceName amount damageTypeName", isDamageShield = true },
	DAMAGESHIELDOTHEROTHER = { "damage", "", "sourceName amount damageTypeName recipientName", isDamageShield = true },

	-- Heals.
	HEALEDSELFOTHER = { "heal", "S", "skillName recipientName amount" }, -- Your %s heals %s for %d.
	HEALEDCRITSELFOTHER = { "heal", "S", "skillName recipientName amount", isCrit = true },
	HEALEDSELFSELF = { "heal", "SR", "skillName amount" },
	HEALEDCRITSELFSELF = { "heal", "SR", "skillName amount", isCrit = true },
	HEALEDOTHERSELF = { "heal", "R", "sourceName skillName amount" }, -- %s's %s heals you for %d.
	HEALEDCRITOTHERSELF = { "heal", "R", "sourceName skillName amount", isCrit = true },
	HEALEDOTHEROTHER = { "heal", "", "sourceName skillName recipientName amount" },
	HEALEDCRITOTHEROTHER = { "heal", "", "sourceName skillName recipientName amount", isCrit = true },
	PERIODICAURAHEALSELFOTHER = { "heal", "S", "recipientName amount skillName", isHoT = true }, -- %s gains %d health from your %s.
	PERIODICAURAHEALSELFSELF = { "heal", "SR", "amount skillName", isHoT = true }, -- You gain %d health from %s.
	PERIODICAURAHEALOTHERSELF = { "heal", "R", "amount sourceName skillName", isHoT = true }, -- You gain %d health from %s's %s.
	PERIODICAURAHEALOTHEROTHER = { "heal", "", "recipientName amount sourceName skillName", isHoT = true },

	-- Power gains, drains and leeches.
	POWERGAINSELFSELF = { "power", "SR", "amount powerTypeName skillName" }, -- You gain %d %s from %s.
	POWERGAINOTHERSELF = { "power", "R", "amount powerTypeName sourceName skillName" }, -- You gain %d %s from %s's %s.
	POWERGAINSELFOTHER = { "power", "", "recipientName amount powerTypeName skillName" }, -- %s gains %d %s from %s.
	POWERGAINOTHEROTHER = { "power", "", "recipientName amount powerTypeName sourceName skillName" },
	SPELLPOWERDRAINSELFOTHER = { "power", "S", "skillName amount powerTypeName recipientName", isDrain = true }, -- Your %s drains %d %s from %s.
	SPELLPOWERDRAINOTHERSELF = { "power", "R", "sourceName skillName amount powerTypeName", isDrain = true },
	SPELLPOWERDRAINSELFSELF = { "power", "SR", "skillName amount powerTypeName", isDrain = true },
	SPELLPOWERDRAINOTHEROTHER = { "power", "", "sourceName skillName amount powerTypeName recipientName", isDrain = true },
	SPELLPOWERLEECHSELFOTHER = { "power", "S", "skillName amount powerTypeName recipientName extraAmount extraPowerTypeName", isLeech = true }, -- Your %s drains %d %s from %s. You gain %d %s.
	SPELLPOWERLEECHOTHERSELF = { "power", "R", "sourceName skillName amount powerTypeName - extraAmount extraPowerTypeName", isDrain = true },
	SPELLPOWERLEECHOTHEROTHER = { "power", "", "sourceName skillName amount powerTypeName recipientName - extraAmount extraPowerTypeName", isDrain = true },

	-- Auras.
	AURAADDEDSELFHELPFUL = { "aura", "R", "skillName", auraType = "BUFF" }, -- You gain %s.
	AURAADDEDSELFHARMFUL = { "aura", "R", "skillName", auraType = "DEBUFF" }, -- You are afflicted by %s.
	AURAAPPLICATIONADDEDSELFHELPFUL = { "aura", "R", "skillName amountStacks", auraType = "BUFF", isDose = true }, -- You gain %s (%d).
	AURAAPPLICATIONADDEDSELFHARMFUL = { "aura", "R", "skillName amountStacks", auraType = "DEBUFF", isDose = true },
	AURAADDEDOTHERHELPFUL = { "aura", "", "recipientName skillName", auraType = "BUFF" }, -- %s gains %s.
	AURAADDEDOTHERHARMFUL = { "aura", "", "recipientName skillName", auraType = "DEBUFF" },
	AURAAPPLICATIONADDEDOTHERHELPFUL = { "aura", "", "recipientName skillName amountStacks", auraType = "BUFF", isDose = true },
	AURAAPPLICATIONADDEDOTHERHARMFUL = { "aura", "", "recipientName skillName amountStacks", auraType = "DEBUFF", isDose = true },
	AURAREMOVEDSELF = { "aura", "R", "skillName", isFade = true }, -- %s fades from you.
	AURAREMOVEDOTHER = { "aura", "", "skillName recipientName", isFade = true }, -- %s fades from %s.

	-- Dispels. 1.12 does not name the dispeller; see Parser.lua.
	AURADISPELSELF = { "dispel", "R", "extraSkillName" }, -- Your %s is removed.
	AURADISPELOTHER = { "dispel", "", "recipientName extraSkillName" }, -- %s's %s is removed.

	-- Interrupts.
	SPELLINTERRUPTSELFOTHER = { "interrupt", "S", "recipientName extraSkillName" }, -- You interrupt %s's %s.
	SPELLINTERRUPTOTHERSELF = { "interrupt", "R", "sourceName extraSkillName" }, -- %s interrupts your %s.
	SPELLINTERRUPTOTHEROTHER = { "interrupt", "", "sourceName recipientName extraSkillName" },

	-- Extra attacks.
	SPELLEXTRAATTACKSSELF = { "extraattacks", "S", "amount skillName" }, -- You gain %d extra attacks through %s.
	SPELLEXTRAATTACKSSELF_SINGULAR = { "extraattacks", "S", "amount skillName" },
	SPELLEXTRAATTACKSOTHER = { "extraattacks", "", "sourceName amount skillName" },
	SPELLEXTRAATTACKSOTHER_SINGULAR = { "extraattacks", "", "sourceName amount skillName" },

	-- Item enchantments.
	ITEMENCHANTMENTADDSELFSELF = { "enchant", "SR", "skillName itemName" }, -- You cast %s on your %s.
	ITEMENCHANTMENTADDOTHERSELF = { "enchant", "R", "sourceName skillName itemName" },
	ITEMENCHANTMENTREMOVESELF = { "enchant", "R", "skillName itemName", isFade = true }, -- %s has faded from your %s.

	-- Environmental damage.
	VSENVIRONMENTALDAMAGE_DROWNING_SELF = { "environmental", "R", "amount", hazardType = "DROWNING" },
	VSENVIRONMENTALDAMAGE_FALLING_SELF = { "environmental", "R", "amount", hazardType = "FALLING" },
	VSENVIRONMENTALDAMAGE_FATIGUE_SELF = { "environmental", "R", "amount", hazardType = "FATIGUE" },
	VSENVIRONMENTALDAMAGE_FIRE_SELF = { "environmental", "R", "amount", hazardType = "FIRE" },
	VSENVIRONMENTALDAMAGE_LAVA_SELF = { "environmental", "R", "amount", hazardType = "LAVA" },
	VSENVIRONMENTALDAMAGE_SLIME_SELF = { "environmental", "R", "amount", hazardType = "SLIME" },

	-- Deaths.
	SELFKILLOTHER = { "kill", "S", "recipientName" }, -- You have slain %s!
	PARTYKILLOTHER = { "kill", "", "recipientName sourceName" }, -- %s is slain by %s!
	UNITDIESOTHER = { "death", "", "recipientName" }, -- %s dies.
	UNITDESTROYEDOTHER = { "death", "", "recipientName" },

	-- Casts (only used by triggers).
	SPELLCASTOTHERSTART = { "cast", "", "sourceName skillName", castStage = "START" }, -- %s begins to cast %s.
	SPELLPERFORMOTHERSTART = { "cast", "", "sourceName skillName", castStage = "START" },
	SPELLCASTSELFSTART = { "cast", "S", "skillName", castStage = "START" },
	SPELLPERFORMSELFSTART = { "cast", "S", "skillName", castStage = "START" },
	SPELLCASTGOSELF = { "cast", "S", "skillName", castStage = "SUCCESS" }, -- You cast %s.
	SPELLCASTGOSELFTARGETTED = { "cast", "S", "skillName recipientName", castStage = "SUCCESS" },
	SPELLCASTGOOTHER = { "cast", "", "sourceName skillName", castStage = "SUCCESS" },
	SPELLCASTGOOTHERTARGETTED = { "cast", "", "sourceName skillName recipientName", castStage = "SUCCESS" },
	SPELLPERFORMGOSELF = { "cast", "S", "skillName", castStage = "SUCCESS" },
	SPELLPERFORMGOSELFTARGETTED = { "cast", "S", "skillName recipientName", castStage = "SUCCESS" },
	SPELLPERFORMGOOTHER = { "cast", "", "sourceName skillName", castStage = "SUCCESS" },
	SPELLPERFORMGOOTHERTARGETTED = { "cast", "", "sourceName skillName recipientName", castStage = "SUCCESS" },
	SIMPLECASTSELFOTHER = { "cast", "S", "skillName recipientName", castStage = "SUCCESS" },
	SIMPLECASTSELFSELF = { "cast", "SR", "skillName", castStage = "SUCCESS" },
	SIMPLECASTOTHERSELF = { "cast", "R", "sourceName skillName", castStage = "SUCCESS" },
	SIMPLECASTOTHEROTHER = { "cast", "", "sourceName skillName recipientName", castStage = "SUCCESS" },
	SPELLFAILCASTSELF = { "cast", "S", "skillName missType", castStage = "FAILED" }, -- You fail to cast %s: %s.
	SPELLFAILPERFORMSELF = { "cast", "S", "skillName missType", castStage = "FAILED" },
}

-- Channel-specific strings. These never appear on the combat channels, and
-- some of them ("You gain %d experience.") would otherwise shadow combat
-- strings.
T.notification = {
	CHAT_MSG_COMBAT_HONOR_GAIN = {
		COMBATLOG_HONORGAIN = { "honor", "R", "sourceName sourceRank amount" },
		COMBATLOG_HONORAWARD = { "honor", "R", "amount" },
		COMBATLOG_DISHONORGAIN = { "honor", "R", "sourceName", isDishonor = true },
	},
	CHAT_MSG_COMBAT_FACTION_CHANGE = {
		FACTION_STANDING_INCREASED = { "reputation", "R", "factionName amount" },
		FACTION_STANDING_DECREASED = { "reputation", "R", "factionName amount", isLoss = true },
	},
	CHAT_MSG_SKILL = {
		SKILL_RANK_UP = { "proficiency", "R", "skillName amount" },
	},
	CHAT_MSG_COMBAT_XP_GAIN = {
		COMBATLOG_XPGAIN_FIRSTPERSON = { "experience", "R", "sourceName amount" },
		COMBATLOG_XPGAIN_FIRSTPERSON_GROUP = { "experience", "R", "sourceName amount -" },
		COMBATLOG_XPGAIN_FIRSTPERSON_RAID = { "experience", "R", "sourceName amount -" },
		COMBATLOG_XPGAIN_EXHAUSTION1 = { "experience", "R", "sourceName amount - -" },
		COMBATLOG_XPGAIN_EXHAUSTION1_GROUP = { "experience", "R", "sourceName amount - - -" },
		COMBATLOG_XPGAIN_EXHAUSTION1_RAID = { "experience", "R", "sourceName amount - - -" },
		COMBATLOG_XPGAIN_EXHAUSTION2 = { "experience", "R", "sourceName amount - -" },
		COMBATLOG_XPGAIN_EXHAUSTION2_GROUP = { "experience", "R", "sourceName amount - - -" },
		COMBATLOG_XPGAIN_EXHAUSTION2_RAID = { "experience", "R", "sourceName amount - - -" },
		COMBATLOG_XPGAIN_EXHAUSTION4 = { "experience", "R", "sourceName amount - -" },
		COMBATLOG_XPGAIN_EXHAUSTION4_GROUP = { "experience", "R", "sourceName amount - - -" },
		COMBATLOG_XPGAIN_EXHAUSTION4_RAID = { "experience", "R", "sourceName amount - - -" },
		COMBATLOG_XPGAIN_EXHAUSTION5 = { "experience", "R", "sourceName amount - -" },
		COMBATLOG_XPGAIN_EXHAUSTION5_GROUP = { "experience", "R", "sourceName amount - - -" },
		COMBATLOG_XPGAIN_EXHAUSTION5_RAID = { "experience", "R", "sourceName amount - - -" },
		COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED = { "experience", "R", "amount" },
		COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_GROUP = { "experience", "R", "amount -" },
		COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED_RAID = { "experience", "R", "amount -" },
	},
	CHAT_MSG_LOOT = {
		LOOT_ITEM_SELF = { "loot", "R", "itemLink" }, -- You receive loot: %s.
		LOOT_ITEM_SELF_MULTIPLE = { "loot", "R", "itemLink amount" }, -- You receive loot: %sx%d.
		LOOT_ITEM_PUSHED_SELF = { "loot", "R", "itemLink" },
		LOOT_ITEM_PUSHED_SELF_MULTIPLE = { "loot", "R", "itemLink amount" },
		LOOT_ITEM_CREATED_SELF = { "loot", "R", "itemLink", isCreate = true },
		LOOT_ITEM_CREATED_SELF_MULTIPLE = { "loot", "R", "itemLink amount", isCreate = true },
	},
	CHAT_MSG_MONEY = {
		YOU_LOOT_MONEY = { "loot", "R", "moneyString", isMoney = true }, -- You loot %s
		LOOT_MONEY_SPLIT = { "loot", "R", "moneyString", isMoney = true },
	},
}

-- Partial effect trailers, removed from the message before matching.
T.trailers = {
	{ "ABSORB_TRAILER", "absorbAmount" },
	{ "BLOCK_TRAILER", "blockAmount" },
	{ "RESIST_TRAILER", "resistAmount" },
	{ "VULNERABLE_TRAILER", "vulnerableAmount" },
	{ "CRUSHING_TRAILER", "isCrushing" },
	{ "GLANCING_TRAILER", "isGlancing" },
}

-- Chat channels carrying combat log lines. Every combat string is tried on
-- every channel: the channel a line arrives on is not relied upon, so a client
-- that routes a line differently still gets it parsed.
T.combatEvents = {
	"CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_COMBAT_SELF_MISSES",
	"CHAT_MSG_COMBAT_PET_HITS", "CHAT_MSG_COMBAT_PET_MISSES",
	"CHAT_MSG_COMBAT_PARTY_HITS", "CHAT_MSG_COMBAT_PARTY_MISSES",
	"CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS", "CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES",
	"CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS", "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES",
	"CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES",
	"CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES",
	"CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES",
	"CHAT_MSG_COMBAT_HOSTILE_DEATH", "CHAT_MSG_COMBAT_FRIENDLY_DEATH",
	"CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_SELF_BUFF",
	"CHAT_MSG_SPELL_PET_DAMAGE", "CHAT_MSG_SPELL_PET_BUFF",
	"CHAT_MSG_SPELL_PARTY_DAMAGE", "CHAT_MSG_SPELL_PARTY_BUFF",
	"CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE", "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
	"CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
	"CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF",
	"CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF",
	"CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF",
	"CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
	"CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
	"CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
	"CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS",
	"CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
	"CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF", "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS",
	"CHAT_MSG_SPELL_AURA_GONE_SELF", "CHAT_MSG_SPELL_AURA_GONE_OTHER", "CHAT_MSG_SPELL_AURA_GONE_PARTY",
	"CHAT_MSG_SPELL_ITEM_ENCHANTMENTS", "CHAT_MSG_SPELL_BREAK_AURA",
}
