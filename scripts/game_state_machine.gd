## 游戏状态机
## 对应原 Python: core/state_machine.py
## 管理回合阶段流转：出牌→结算→回合结束
extends Node

enum TurnPhase {
	DRAW,
	PLAY_P1,
	PLAY_P2,
	RESOLVE,
	REMEDY,
	REMEDY_AI,
	ROUND_END,
	GAME_OVER,
}

const MANA_HARD_CAP: int = 10
const MANA_INITIAL: int = 5
const AI_DELAY_MS: float = 3.0
const REMEDY_TIMEOUT: float = 30.0
const REMEDY_AI_DELAY: float = 2.0
const ROUND_END_DELAY: float = 0.6

var current_phase: TurnPhase = TurnPhase.DRAW
var first_player: String = "P1"
var phase_timer: float = 0.0

# 游戏状态
var players: Dictionary = {}
var hands: Dictionary = {}
var deck: DeckManager
var played_cards: Dictionary = {}
var pending_play: Dictionary = {}
var winner: String = ""
var round_count: int = 0

# 精力系统
var max_mana: int = MANA_INITIAL
var current_mana: int = MANA_INITIAL

signal phase_changed(new_phase: TurnPhase)
signal hp_changed(player: String, new_hp: int)
signal game_over(winner: String)

func _ready() -> void:
	players = {
		"P1": {"hp": 10, "max_hp": 10},
		"P2": {"hp": 10, "max_hp": 10},
	}
	hands = {"P1": [], "P2": []}
	played_cards = {"P1": [], "P2": []}
	pending_play = {"P1": [], "P2": []}

func start_game(deck_cards: Array[CardData]) -> void:
	"""开始新游戏，发牌"""
	deck = DeckManager.new(deck_cards)
	deck.shuffle()
	hands["P1"] = deck.draw(5)
	hands["P2"] = deck.draw(5)
	round_count = 1
	max_mana = MANA_INITIAL
	current_mana = max_mana
	_change_phase(TurnPhase.PLAY_P1 if first_player == "P1" else TurnPhase.PLAY_P2)

func _change_phase(new_phase: TurnPhase) -> void:
	current_phase = new_phase
	phase_timer = 0.0
	emit_signal("phase_changed", new_phase)
	
	match new_phase:
		TurnPhase.PLAY_P1:
			current_mana = max_mana
		TurnPhase.PLAY_P2:
			current_mana = max_mana

func play_card(card: CardData, player: String) -> bool:
	"""玩家出牌"""
	if current_mana < card.cost:
		return false
	current_mana -= card.cost
	hands[player].erase(card)
	pending_play[player].append(card)
	return true

func finish_p1_turn() -> void:
	"""P1 结束出牌，提交到战场"""
	played_cards["P1"] = pending_play["P1"].duplicate()
	pending_play["P1"].clear()
	_change_phase(TurnPhase.PLAY_P2)

func undo_play_card(card: CardData, player: String) -> bool:
	"""撤回预出的牌"""
	if card in pending_play[player]:
		pending_play[player].erase(card)
		current_mana += card.cost
		hands[player].append(card)
		return true
	return false

func _process(delta: float) -> void:
	phase_timer += delta
	
	match current_phase:
		TurnPhase.PLAY_P2:
			if phase_timer >= AI_DELAY_MS:
				_ai_play()
		TurnPhase.ROUND_END:
			if phase_timer >= ROUND_END_DELAY:
				_next_round()
		TurnPhase.REMEDY:
			if phase_timer >= REMEDY_TIMEOUT:
				winner = "P2"
				_change_phase(TurnPhase.GAME_OVER)
		TurnPhase.REMEDY_AI:
			if phase_timer >= REMEDY_AI_DELAY:
				_ai_remedy()

func _ai_play() -> void:
	"""AI 自动出牌（简单AI）"""
	_change_phase(TurnPhase.RESOLVE)
	# TODO: 接入 AI 逻辑 + 结算引擎

func _next_round() -> void:
	"""进入下一回合"""
	played_cards["P1"].clear()
	played_cards["P2"].clear()
	pending_play["P1"].clear()
	pending_play["P2"].clear()
	round_count += 1
	# 精力上限增长
	if max_mana < MANA_HARD_CAP:
		max_mana += 1
	# 补牌
	if deck and not deck.is_empty():
		var drawn = deck.draw(1)
		hands["P1"].append_array(drawn)
	if deck and not deck.is_empty():
		var drawn = deck.draw(1)
		hands["P2"].append_array(drawn)
	_change_phase(TurnPhase.PLAY_P1)

func _ai_remedy() -> void:
	"""AI 补救"""
	_change_phase(TurnPhase.ROUND_END)
