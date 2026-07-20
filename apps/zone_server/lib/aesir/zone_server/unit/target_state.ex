defmodule Aesir.ZoneServer.Unit.TargetState do
  @moduledoc """
  Classifies authoritative unit snapshots for living participation and corpse targeting.

  Spatial storage remains state-agnostic; consumers choose whether they need a
  living unit, a player corpse, or any connected observer.
  """

  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @living_player_actions [
    :idle,
    :moving,
    :combat_moving,
    :skill_moving,
    :moving_to_item,
    :attacking,
    :casting,
    :sitting,
    :trading,
    :vending
  ]

  @doc "Returns true when `snapshot` is a consistent living player or mob state."
  @spec living?(term()) :: boolean()
  def living?(%PlayerState{
        action_state: action_state,
        stats: %{current_state: %{hp: hp}}
      })
      when action_state in @living_player_actions and is_integer(hp) and hp > 0,
      do: true

  def living?(%MobState{is_dead: false, hp: hp}) when is_integer(hp) and hp > 0, do: true

  def living?(_snapshot), do: false

  @doc "Returns true only for a player at zero HP in the dead action state."
  @spec corpse?(term()) :: boolean()
  def corpse?(%PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}), do: true
  def corpse?(_snapshot), do: false
end
