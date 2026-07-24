defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrTrust do
  @moduledoc """
  Faith (CR_TRUST). Always-on passive granting flat max HP and holy damage
  resistance.

  Renewal: `+200` max HP per level, plus `5%` holy-element damage resistance
  per level. The HP bonus folds into the flat max-HP route
  (`Passives.max_hp_bonus/1`, read by `Stats.get_hp_bonus_flat/1`); the holy
  resist is read straight off `Combatant.faith_level` by
  `EquipmentBonuses.damage_taken_rates/4`, applying to both physical and magic
  holy damage.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 248,
    name: :cr_trust,
    display_name: "Faith",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def max_hp_bonus(level, _ctx), do: 200 * level
end
