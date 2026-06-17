defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoberserk do
  @moduledoc """
  Auto Berserk (SC_AUTOBERSERK).

  Passive buff toggled by SM_AUTOBERSERK. Whenever the carrier takes damage
  and post-damage HP falls below 25% of max HP, automatically applies
  SC_PROVOKE at level 10 if not already provoked.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_autoberserk,
    properties: [:buff],
    permanent: true

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def on_damage(target, instance, %{hp_after: hp_after, max_hp: max_hp}, _context)
      when hp_after * 4 < max_hp do
    if has_status?(target, :sc_provoke) do
      {:ok, instance}
    else
      params = [val1: 10, val2: 32, val3: 55]
      {:ok, instance, [{:sc_provoke, params}]}
    end
  end

  def on_damage(_target, instance, _damage_info, _context) do
    {:ok, instance}
  end
end
