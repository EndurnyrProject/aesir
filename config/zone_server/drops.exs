import Config

# Per-item-type drop rate multipliers, as a percentage (100 = 1x). Each mob drop
# slot is scaled by the multiplier for the dropped item's category before the
# renewal 90% cap, level-gap penalty, and the per-category min/max clamp
#
# Category resolution: healing items -> :heal; usable/cash -> :use;
# weapon/armor/pet-armor -> :equip; cards -> :card; everything else -> :common.
# `mvp` scales the MVP-tier boss reward drop slots. `treasure` is reserved for
# treasure-box mobs, which Aesir does not currently model.
config :zone_server,
  item_rate_common: 100,
  item_rate_heal: 100,
  item_rate_use: 100,
  item_rate_equip: 100,
  item_rate_card: 100,
  item_rate_mvp: 100,
  item_rate_treasure: 100

# Per-category drop rate floor/ceiling, in 1/10000 units, applied after the rate
# multiplier and level penalty.
# Defaults reproduce the previous global 1..10000 clamp.
config :zone_server,
  item_drop_common_min: 1,
  item_drop_common_max: 10_000,
  item_drop_heal_min: 1,
  item_drop_heal_max: 10_000,
  item_drop_use_min: 1,
  item_drop_use_max: 10_000,
  item_drop_equip_min: 1,
  item_drop_equip_max: 10_000,
  item_drop_card_min: 1,
  item_drop_card_max: 10_000,
  item_drop_mvp_min: 1,
  item_drop_mvp_max: 10_000,
  item_drop_treasure_min: 1,
  item_drop_treasure_max: 10_000
