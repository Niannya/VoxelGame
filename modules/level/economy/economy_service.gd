## L06 共享金币：只做"钱怎么进、怎么出"，不碰 UI 和商人货架。
##
## 已实现：共享余额、按物品基础价结算卖矿、扣钱。
## 未实现：熔炉厌食/自助餐/点菜/收购热潮的连击计时与加价、商人货架、押运任务
## （见 Docs/Dev/关卡缺口清单.md）。加价规则接入点见 `apply_sale_modifier()`。
##
## 给其他模块的约定：
## - 任何模块都能读 `coins`，但**只有本节点**能改；改就听 `coins_changed`。
## - 卖矿必须走 `sell()`，这样以后加价才不会漏。
class_name LevelEconomyService
extends Node

signal coins_changed(total: int)
signal sale_settled(earned: int, items: Array)

## 开局金币（首测 0）。
@export var starting_coins: int = 0

var coins: int = 0


func _ready() -> void:
	coins = starting_coins
	coins_changed.emit(coins)


## 卖一批物品。items 元素至少要有 price；其余字段原样回传给 UI。
## 返回本次实际到账的金币。
func sell(items: Array) -> int:
	if items.is_empty():
		return 0
	var total := 0
	for item in items:
		var price := int(item.get("price", 0))
		total += apply_sale_modifier(item, price)
	if total <= 0:
		return 0
	coins += total
	coins_changed.emit(coins)
	sale_settled.emit(total, items)
	return total


## 单件加价/减价的扩展点。熔炉事件接进来时改这里，别改 sell()。
## 返回值向下取整后累加，与需求案"尾数向下取整"一致。
func apply_sale_modifier(_item: Dictionary, base_price: int) -> int:
	return base_price


func can_afford(price: int) -> bool:
	return coins >= price


## 扣钱。余额不足返回 false，且不改变余额。
func try_spend(price: int) -> bool:
	if price <= 0:
		return true
	if coins < price:
		return false
	coins -= price
	coins_changed.emit(coins)
	return true


## 直接调整（事件奖励、押运结算）。
func grant(amount: int) -> void:
	if amount == 0:
		return
	coins += amount
	coins_changed.emit(coins)
