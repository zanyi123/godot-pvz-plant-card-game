## 牌堆管理器
## 对应原 Python: core/models.py 中的 Deck 类
class_name DeckManager

var cards: Array[CardData] = []

func _init(deck_cards: Array[CardData] = []) -> void:
	cards = deck_cards.duplicate()

func shuffle() -> void:
	cards.shuffle()

func draw(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for i in range(min(count, cards.size())):
		drawn.append(cards.pop_front())
	return drawn

func is_empty() -> bool:
	return cards.is_empty()

func size() -> int:
	return cards.size()
