defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LexAeterna do
  @moduledoc """
  Lex Aeterna (SC_AETERNA).

  Marks the target so the next qualifying hit deals double damage, then fades.
  Freeze and Stone prevent the status, while Soul Breaker's physical part and
  Soul Burn do not double or consume it (rAthena).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_aeterna,
    no_dispel: false,
    properties: [:debuff],
    conflicts_with: [:sc_freeze, :sc_stone],
    prevented_by: [:sc_refresh, :sc_inspiration]

  @impl true
  def absorb_damage(_target, instance, %{damage: damage} = hit, _context) when damage > 0 do
    if qualifying_hit?(hit), do: {:remove, damage * 2}, else: {:ok, damage, instance}
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}

  @spec qualifying_hit?(map()) :: boolean()
  def qualifying_hit?(%{skill_id: 379, dmg_type: :physical}), do: false
  def qualifying_hit?(%{skill_id: 375}), do: false
  def qualifying_hit?(_hit), do: true
end
