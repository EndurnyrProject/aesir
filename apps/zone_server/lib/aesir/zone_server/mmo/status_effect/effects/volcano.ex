defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Volcano do
  @moduledoc """
  Volcano (SC_VOLCANO), the fire field buff left by the Sage's Volcano.

  Every occupant's fire attack gains the tabulated element points. Renewal grants
  everyone 5 plus 5 per level ATK and MATK (weapon ATK for mobs); pre-renewal grants
  10 per level weapon ATK to fire-element holders only.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_volcano,
    no_dispel: false,
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
      {:renewal, :mob} -> %{watk: 5 + 5 * level}
      {:renewal, _player} -> %{atk: 5 + 5 * level, matk: 5 + 5 * level}
      {:pre_renewal, _any} -> %{watk: 10 * level}
    end
  end
end
