defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LexAeterna do
  @moduledoc """
  Lex Aeterna (SC_AETERNA).

  Marks the target so the next attack doubles, first in the common damage stage,
  then fades. Freeze and Stone prevent the status.

  Soul Burn neither doubles nor consumes it. A mercenary's skill consumes it
  without doubling. In pre-renewal the weapon part of Soul Breaker doubles
  without consuming it, so its later non-weapon part doubles and consumes it.
  Damage that is not an attack (poison and bleeding ticks, HP costs such as
  Sacrifice or Berserk drain) never reaches it.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_aeterna,
    no_dispel: false,
    properties: [:debuff],
    conflicts_with: [:sc_freeze, :sc_stone],
    prevented_by: [:sc_refresh, :sc_inspiration]

  alias Aesir.Commons.GameMode

  @soul_burn 375
  @soul_breaker 379

  @impl true
  def absorb_damage(_target, instance, %{damage: damage} = hit, _context) when damage > 0 do
    skill_id = Map.get(hit, :skill_id)

    cond do
      skill_id == @soul_burn -> {:ok, damage, instance}
      mercenary_skill?(hit, skill_id) -> {:remove, damage}
      breaker_weapon_part?(hit, skill_id) -> {:ok, damage * 2, instance}
      true -> {:remove, damage * 2}
    end
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  defp mercenary_skill?(%{attacker: {:mercenary, _id}}, skill_id), do: is_integer(skill_id)
  defp mercenary_skill?(_hit, _skill_id), do: false

  defp breaker_weapon_part?(%{dmg_type: :physical}, @soul_breaker),
    do: GameMode.mode() == :pre_renewal

  defp breaker_weapon_part?(_hit, _skill_id), do: false
end
