defmodule Aesir.ZoneServer.Mmo.Combat.SpDrain do
  @moduledoc """
  Equipment-granted SP restoration on normal attacks.

  A landed swing restores its flat equipment value, then rolls a per-mille
  chance to add a percentage of the damage dealt. The roll is kept separate
  from the attack path so that path only routes the restoration to the
  attacker's session.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant

  @per_mille 1_000

  @doc "Returns the SP the attacker restores from a landed normal hit."
  @spec roll(Combatant.t(), integer()) :: non_neg_integer()
  def roll(%Combatant{} = attacker, damage) when is_integer(damage) do
    if damage > 0 do
      flat = max(Map.get(attacker.equip_modifiers, :sp_drain_value, 0), 0)
      rate = Map.get(attacker.equip_modifiers, :sp_drain_rate, 0)
      percent = Map.get(attacker.equip_modifiers, :sp_drain_percent, 0)

      proc =
        if rate > 0 and percent > 0 and :rand.uniform(@per_mille) <= rate do
          max(div(damage * percent, 100), 0)
        else
          0
        end

      flat + proc
    else
      0
    end
  end
end
