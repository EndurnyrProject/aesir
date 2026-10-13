defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Volcano do
  @moduledoc """
  Volcano (SC_VOLCANO), the fire field buff left by the Sage's Volcano.

  Every occupant's fire attack gains the tabulated element points. Renewal grants
  everyone 5 plus 5 per level status ATK and MATK; pre-renewal grants 10 per
  level to fire-element holders only, as status ATK for players and homunculi
  and as weapon ATK for monsters, which have no status ATK.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_volcano,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:atk, :matk, :watk],
    no_save: true,
    icon: :groundmagic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.FieldElement

  @impl true
  def modifiers(instance, context) do
    level = instance.val1
    ratio = %{{:element_ratio, :fire} => FieldElement.enchant_bonus(level)}

    if FieldElement.stat_bonus?(context, :fire),
      do: Map.merge(ratio, attack_modifiers(level, Map.get(context, :unit_type))),
      else: ratio
  end

  defp attack_modifiers(level, unit_type) do
    case {GameMode.mode(), unit_type} do
      {:renewal, _any} -> %{batk: 5 + 5 * level, matk: 5 + 5 * level}
      {:pre_renewal, :mob} -> %{watk: 10 * level}
      {:pre_renewal, _any} -> %{batk: 10 * level}
    end
  end
end
