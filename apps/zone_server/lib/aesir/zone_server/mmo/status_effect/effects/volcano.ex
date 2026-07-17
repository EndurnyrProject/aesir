defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Volcano do
  @moduledoc """
  Volcano (SC_VOLCANO), the fire field buff left by Sage's SA_VOLCANO.

  Applies to every unit standing on the field. In renewal the bonus is
  unconditional: unlike pre-renewal, the holder's defense element no longer
  gates it (`status.cpp:10994-11007`).

  Grants `5 + 5 * level` attack power and raises the holder's fire-element
  attack ratio by a tabulated number of percentage points
  (`battle.cpp:531-537`, applied on top of the element table).

  The attack bonus splits by unit type, mirroring rAthena:

    - players get `:atk` and `:matk` (`status.cpp:7300-7301`, `7447-7448`)
    - mobs get `:watk` (`status.cpp:7352-7353`, gated on `BL_MOB`)

  rAthena's `batk` maps onto Aesir's `:atk` modifier key, which only the player
  stat recalc consumes; `:watk` is flat weapon ATK read by the physical damage
  calculator for any attacker, so the split is preserved by gating on the
  context's `:unit_type`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_volcano,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk, :matk, :watk],
    no_save: true,
    icon: :groundmagic

  alias Aesir.ZoneServer.Mmo.StatusEffect.FieldElement

  @impl true
  def modifiers(instance, context) do
    level = instance.val1

    Map.put(
      attack_modifiers(5 + 5 * level, Map.get(context, :unit_type)),
      {:element_ratio, :fire},
      FieldElement.enchant_bonus(level)
    )
  end

  defp attack_modifiers(bonus, :mob), do: %{watk: bonus}
  defp attack_modifiers(bonus, _unit_type), do: %{atk: bonus, matk: bonus}
end
