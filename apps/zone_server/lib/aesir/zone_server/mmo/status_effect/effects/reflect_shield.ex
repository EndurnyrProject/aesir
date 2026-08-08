defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ReflectShield do
  @moduledoc """
  Reflect Shield (SC_REFLECTSHIELD).

  Toggled by CR_REFLECTSHIELD while a shield is equipped. Implements
  `after_damage_taken/4`: `val1` carries the skill level, and every short-range
  physical hit that is neither reflected nor redirected reflects
  `(10 + 3 * val1)` percent of the delivered damage back to the attacker.

  The shield requirement is checked at cast time; the `:remove_on_unequip_shield`
  flag drops the stance if the shield is later removed without a replacement.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_reflectshield,
    no_dispel: false,
    permanent: true,
    no_save: true,
    properties: [:buff],
    flags: [:remove_on_unequip_shield],
    icon: :reflectshield

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @impl true
  @spec after_damage_taken({atom(), integer()}, StatusEntry.t(), map(), map()) ::
          :ok | {:reflect, non_neg_integer()}
  def after_damage_taken(target, %StatusEntry{val1: level}, hit_info, _context) do
    if reflectable?(hit_info) do
      amount = div(hit_info.damage * (10 + 3 * level), 100)

      if amount > 0 do
        SpecialEffect.play(target, :reflectshield, :area)
        {:reflect, amount}
      else
        :ok
      end
    else
      :ok
    end
  end

  defp reflectable?(hit_info) do
    Map.get(hit_info, :dmg_type) == :physical and
      Map.get(hit_info, :is_short, false) == true and
      not Map.get(hit_info, :reflected, false) and
      not Map.get(hit_info, :redirected, false)
  end
end
