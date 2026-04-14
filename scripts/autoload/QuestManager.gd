# QuestManager.gd
extends Node
# Quest definitions are embedded in World.gd WORLD_QUESTS and WORLD_ITEMS
# This provides a global interface for quest state queries

func get_quests(world:String)->Array:
	# Each world has 1 main collection quest
	match world:
		"math":    return [{"id":"mq1","title":"Lost Formula Stones","item_ids":["ms1","ms2","ms3"],"reward_xp":200,"reward_gold":50,"steps":["Find the 3 Formula Stones!","Stone 1 found!","Stone 2 found!","All stones found! Return to Equa."],"reward_msg":"Quest complete!\n+200 XP! +50 Gold!"}]
		"english": return [{"id":"eq1","title":"Missing Word Scrolls","item_ids":["es1","es2","es3"],"reward_xp":200,"reward_gold":50,"steps":["Find the 3 Word Scrolls!","Scroll 1 found!","Scroll 2 found!","All scrolls found! Return to Vela."],"reward_msg":"Quest complete!\n+200 XP! +50 Gold!"}]
		"music":   return [{"id":"muq1","title":"The Lost Notes","item_ids":["mus1","mus2","mus3"],"reward_xp":200,"reward_gold":50,"steps":["Find the 3 Musical Notes!","Note 1 found!","Note 2 found!","All notes found! Return to Aria."],"reward_msg":"Quest complete!\n+200 XP! +50 Gold!"}]
	return []

func get_active_quest(world:String)->Dictionary:
	for q in get_quests(world):
		if not GameManager.quest_done(q.id): return q
	return {}

func get_quest_step(quest:Dictionary)->int:
	if quest.is_empty(): return 0
	var count:=0
	for iid in quest.get("item_ids",[]): if GameManager.has_item(iid): count+=1
	return count

func all_items_collected(quest:Dictionary)->bool:
	for iid in quest.get("item_ids",[]): if not GameManager.has_item(iid): return false
	return true
