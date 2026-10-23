class_name DeckController
extends RefCounted

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var exhaust_pile: Array[CardData] = []

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var pending_cost_penalty: int = 0
var next_tag_cost_delta: Dictionary = {}
var next_card_cost_delta: int = 0

func setup(deck_ids: Array[String], card_db: Dictionary, seed_value: int) -> void:
	rng.seed = seed_value
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	pending_cost_penalty = 0
	next_tag_cost_delta.clear()
	next_card_cost_delta = 0
	for id in deck_ids:
		var card: CardData = card_db.get(id, null) as CardData
		if card == null:
			card = Util.load_card_by_id(id)
		if card != null:
			draw_pile.append(card)
	shuffle_draw()

func shuffle_draw() -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: CardData = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp

func draw_cards(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for _i in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			shuffle_draw()
		var card: CardData = draw_pile.pop_back()
		hand.append(card)
		drawn.append(card)
	return drawn

func discard_hand() -> void:
	while not hand.is_empty():
		discard_pile.append(hand.pop_back())

# 回合结束弃牌时，将 ethereal（虚化）卡牌送入消耗堆而非弃牌堆
func discard_hand_with_ethereal() -> void:
	while not hand.is_empty():
		var card: CardData = hand.pop_back()
		if card != null and card.ethereal:
			exhaust_pile.append(card)
		else:
			discard_pile.append(card)

func play_from_hand(index: int) -> CardData:
	if index < 0 or index >= hand.size():
		return null
	return hand.pop_at(index)

func send_to_discard(card: CardData) -> void:
	discard_pile.append(card)

func send_to_exhaust(card: CardData) -> void:
	exhaust_pile.append(card)

func effective_cost(card: CardData) -> int:
	var cost: int = card.cost
	if pending_cost_penalty > 0:
		cost += pending_cost_penalty
	cost += next_card_cost_delta
	for tag in card.tags:
		if next_tag_cost_delta.has(tag):
			cost += int(next_tag_cost_delta[tag])
	return max(0, cost)

func consume_tag_cost_delta(card: CardData) -> void:
	if next_card_cost_delta != 0:
		next_card_cost_delta = 0
	# 消耗所有匹配标签的费用增量（与 effective_cost 的求和逻辑对称）
	for tag in card.tags:
		next_tag_cost_delta.erase(tag)

func add_to_hand(card: CardData) -> void:
	if card != null:
		hand.append(card)

func add_to_discard(card: CardData) -> void:
	if card != null:
		discard_pile.append(card)

func add_to_draw(card: CardData, to_top: bool = true) -> void:
	if card == null:
		return
	if to_top:
		draw_pile.append(card)
	else:
		draw_pile.push_front(card)
