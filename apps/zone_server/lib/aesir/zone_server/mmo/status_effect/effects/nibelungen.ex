defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Nibelungen do
  @moduledoc """
  Ring of Nibelungen (SC_NIBELUNGEN), the ensemble's party buff.

  Renewal: every application rolls its outcome into `val2`, uniformly over
  `0..11`. Outcome 0 grants nothing; 1 to 11 grant, in order, ASPD +20%,
  status ATK +20%, MATK +20%, Max HP +30%, Max SP +30%, all stats +15,
  HIT +50, FLEE +50, skill SP cost -30%, HP recovery +100% and SP recovery
  +100%. The rolled value itself is also added to the mastery ATK of both
  hands. A status restored at login keeps its rolled value.

  Pre-renewal: the ensemble field starts the status with `val2 = (level + 2) * 25`
  and there is no roll. That value raises the weapon ATK (the weapon roll's
  maximum) of each hand holding a level-4 weapon. The status does not end the
  other ensembles' statuses.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_nibelungen,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [
      :aspd_rate,
      :batk_rate,
      :matk_rate,
      :max_hp_rate,
      :max_sp_rate,
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk,
      :hit,
      :flee,
      :hp_regen,
      :sp_regen,
      :watk
    ],
    end_on_start: [
      renewal: [
        :sc_richmankim,
        :sc_eternalchaos,
        :sc_drumbattle,
        :sc_nibelungen,
        :sc_rokisweil,
        :sc_intoabyss,
        :sc_siegfried
      ],
      pre_renewal: []
    ],
    duration: 60_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :ringnibelungen

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @outcomes 12
  @max_outcome @outcomes - 1
  @sp_consumption 9

  @impl true
  def resolve_duration(instance, duration) do
    case GameMode.mode() do
      :renewal ->
        {rng, state} = Map.pop(instance.state, :rng, &roll/0)
        {duration, %{instance | val2: validate_roll!(rng.()), state: state}}

      :pre_renewal ->
        {duration, instance}
    end
  end

  @impl true
  def modifiers(%{val2: value}, _context) when is_integer(value) do
    case GameMode.mode() do
      :renewal -> value |> outcome_modifiers() |> with_mastery_atk(value)
      :pre_renewal when value > 0 -> %{level4_watk: value}
      :pre_renewal -> %{}
    end
  end

  def modifiers(_instance, _context), do: %{}

  defp outcome_modifiers(1), do: %{aspd_rate: 20}
  defp outcome_modifiers(2), do: %{batk_rate: 20}
  defp outcome_modifiers(3), do: %{matk_rate: 20}
  defp outcome_modifiers(4), do: %{max_hp_rate: 30}
  defp outcome_modifiers(5), do: %{max_sp_rate: 30}
  defp outcome_modifiers(6), do: %{str: 15, agi: 15, vit: 15, int: 15, dex: 15, luk: 15}
  defp outcome_modifiers(7), do: %{hit: 50}
  defp outcome_modifiers(8), do: %{flee: 50}
  defp outcome_modifiers(10), do: %{hp_regen: 100}
  defp outcome_modifiers(11), do: %{sp_regen: 100}
  defp outcome_modifiers(_none), do: %{}

  defp with_mastery_atk(modifiers, 0), do: modifiers
  defp with_mastery_atk(modifiers, value), do: Map.put(modifiers, :mastery_atk, value)

  @doc """
  Applies the renewal SP-consumption outcome to a skill's SP cost: 30% less,
  truncated, after every other rate and flat reduction.
  """
  @spec reduce_sp_cost(non_neg_integer(), StatusEntry.t() | nil) :: non_neg_integer()
  def reduce_sp_cost(sp, %StatusEntry{val2: @sp_consumption}), do: sp - div(sp * 30, 100)
  def reduce_sp_cost(sp, _status), do: sp

  @doc "Rolls a renewal outcome uniformly in `0..11`."
  @spec roll() :: non_neg_integer()
  def roll, do: :rand.uniform(@outcomes) - 1

  defp validate_roll!(roll) when is_integer(roll) and roll in 0..@max_outcome//1, do: roll

  defp validate_roll!(roll) do
    raise ArgumentError,
          "Nibelungen roll must be in 0..#{@max_outcome}, got: #{inspect(roll)}"
  end
end
