defmodule Aesir.ZoneServer.Mmo.Skills.Shared.ItemEnchantarms do
  @moduledoc """
  Weapon Enchant (ITEM_ENCHANTARMS). The endow an item's script casts.

  Not a learnable skill: it exists only as the cast behind the elemental
  converters and the other endowing consumables, which reach it through the
  script `itemskill` primitive. Self-targeted, deals no damage, and endows the
  caster's weapon for a flat 20 minutes at every level.

  The skill level selects the element rather than the strength: the applied
  element id is `level - 1`, so level 1 endows neutral, 2 water, 3 earth,
  4 fire, 5 wind, 6 poison, 7 holy, 8 shadow, 9 ghost and 10 undead. That id is
  handed to `:sc_watk_element` as `val1`, the highest-priority attack-element
  override the damage pipeline reads.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 492,
    name: :item_enchantarms,
    display_name: "Weapon Enchant",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(1, 10),
    duration: List.duplicate(1_200_000, 10)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [
      val1: level - 1,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    case StatusInterpreter.apply_status(:player, caster_id, :sc_watk_element, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
