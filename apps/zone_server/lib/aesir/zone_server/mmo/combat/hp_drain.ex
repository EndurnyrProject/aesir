defmodule Aesir.ZoneServer.Mmo.Combat.HpDrain do
  @moduledoc """
  Equipment-granted HP drain on normal attacks.

  A weapon carrying the drain bonus rolls a per-mille chance on every landed
  swing; on success the attacker recovers a percent of the damage that swing
  dealt as HP. Both halves come from the attacker's own equipment, so an
  attacker carrying none — every mob — never drains.

  The roll lives here rather than in the attack path so it stays a pure
  `(combatant, damage) -> heal` decision the attack path can test and route
  through the owning session.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses

  @per_mille 1_000

  @doc """
  Rolls the attacker's drain chance against `damage` and returns the HP to
  recover.

  Returns `0` — no roll consumed — when the attacker carries no drain rate, no
  drain percent, or the swing dealt no damage, so a miss (which never reaches
  this path) and a zero-damage hit are both inert. The heal is truncated, so a
  drain smaller than one HP recovers nothing.
  """
  @spec roll(Combatant.t(), integer()) :: non_neg_integer()
  def roll(%Combatant{} = attacker, damage) when is_integer(damage) do
    rate = EquipmentBonuses.hp_drain_rate(attacker)
    percent = EquipmentBonuses.hp_drain_percent(attacker)

    if damage > 0 and rate > 0 and percent > 0 and triggered?(rate) do
      max(div(damage * percent, 100), 0)
    else
      0
    end
  end

  defp triggered?(rate), do: :rand.uniform(@per_mille) - 1 < rate
end
