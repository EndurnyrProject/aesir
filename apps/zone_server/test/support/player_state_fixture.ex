defmodule Aesir.ZoneServer.PlayerStateFixture do
  @moduledoc false

  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  def build(%PlayerState{} = state), do: %{state | stats: stats(state.stats)}

  def build(overrides) when is_map(overrides) do
    %PlayerState{action_state: :idle, movement_state: :standing}
    |> struct!(overrides)
    |> build()
  end

  defp stats(%PlayerStats{} = stats) do
    %{
      stats
      | base_stats:
          nested(stats.base_stats, %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1}),
        current_state: nested(stats.current_state, %CurrentState{hp: 100, sp: 100}),
        derived_stats: nested(stats.derived_stats, %DerivedStats{max_hp: 100, max_sp: 100}),
        progression: nested(stats.progression, %PlayerProgression{job_id: 0}),
        equipment: nested(stats.equipment, %Equipment{}),
        modifiers: nested(stats.modifiers, %Modifiers{})
    }
  end

  defp stats(stats) when is_map(stats), do: PlayerStats |> struct!(stats) |> stats()

  defp nested(nil, default), do: default
  defp nested(%module{} = value, %module{}), do: value
  defp nested(value, default) when is_map(value), do: struct!(default, value)
end
