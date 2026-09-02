defmodule Aesir.ZoneServer.Mmo.Combat.EquipComa do
  @moduledoc """
  Pure equipment coma eligibility and chance policy.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses

  @roll_ceiling 10_000

  @typedoc "A per-10,000 roll predicate receiving the effective chance."
  @type roll_fun :: (pos_integer() -> boolean())

  @doc "Decides whether equipment coma triggers for one eligible target."
  @spec trigger?(Combatant.t(), Combatant.t(), keyword()) :: boolean()
  def trigger?(attacker, target, opts \\ [])

  def trigger?(%Combatant{}, %Combatant{status_immune: true}, _opts), do: false

  def trigger?(
        %Combatant{unit_type: :player} = attacker,
        %Combatant{unit_type: target_type} = target,
        opts
      )
      when target_type in [:player, :mob, :homunculus] do
    if competitive_mob?(target) do
      false
    else
      roll = Keyword.get(opts, :roll, &default_roll/1)

      rate =
        EquipmentBonuses.coma_race_rate(attacker, target) +
          EquipmentBonuses.coma_class_rate(attacker, target)

      rate = clamp_rate(rate)
      successful?(rate, roll)
    end
  end

  def trigger?(_attacker, _target, _opts), do: false

  defp competitive_mob?(%Combatant{unit_type: :mob, race2: race2}),
    do: :gvg in race2 or :battlefield in race2

  defp competitive_mob?(_target), do: false

  defp clamp_rate(rate), do: rate |> max(0) |> min(@roll_ceiling)

  defp successful?(@roll_ceiling, _roll), do: true
  defp successful?(rate, roll) when rate > 0, do: roll.(rate)
  defp successful?(_rate, _roll), do: false

  defp default_roll(rate), do: :rand.uniform(@roll_ceiling) <= rate
end
