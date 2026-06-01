extends Node

signal prize_collected(prize: PrizeDefinition, owned_total: int)
signal play_consumed(machine_id: String, coins_remaining: int)
signal play_denied(machine_id: String, reason: String)
