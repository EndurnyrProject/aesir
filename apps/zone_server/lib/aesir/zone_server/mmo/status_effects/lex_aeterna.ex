defmodule Aesir.ZoneServer.Mmo.StatusEffects.LexAeterna do
  @moduledoc """
  Lex Aeterna (SC_AETERNA).

  Marks the target so the next hit deals double damage, then fades. The damage
  doubling awaits a damage-modification hook in the combat engine; the
  consumed-on-hit behavior is implemented here. Cannot be cast on frozen
  targets and Soul Breaker's physical part does not consume it (rAthena).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_aeterna,
    properties: [:debuff],
    conflicts_with: [:sc_freeze],
    prevented_by: [:sc_refresh, :sc_inspiration]

  @impl true
  def on_damage(_target, instance, %{skill_id: :asc_breaker, dmg_type: :physical}, _context) do
    {:ok, instance}
  end

  def on_damage(_target, _instance, _damage_info, _context), do: :remove
end
