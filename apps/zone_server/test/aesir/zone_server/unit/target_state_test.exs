defmodule Aesir.ZoneServer.Unit.TargetStateTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.TargetState

  @living_actions [
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

  describe "living?/1" do
    test "all living player actions require positive HP" do
      for action_state <- @living_actions do
        state = player_state(100, action_state)

        assert TargetState.living?(state)
        refute TargetState.corpse?(state)
      end

      for action_state <- @living_actions do
        refute TargetState.living?(player_state(0, action_state))
      end
    end

    test "a dead player is non-living and is a corpse only at zero HP" do
      corpse = player_state(0, :dead)

      refute TargetState.living?(corpse)
      assert TargetState.corpse?(corpse)
      refute TargetState.corpse?(player_state(1, :dead))
      refute TargetState.corpse?(player_state(-1, :dead))
    end

    test "inconsistent player snapshots fail closed" do
      refute TargetState.living?(player_state(0, :dead))
      refute TargetState.living?(player_state(-1, :idle))
      refute TargetState.living?(player_state(100, :dead))

      refute TargetState.living?(%PlayerState{
               action_state: :unknown,
               stats: %{current_state: %{hp: 100}}
             })

      refute TargetState.corpse?(player_state(-1, :dead))
      refute TargetState.corpse?(player_state(0, :idle))
    end

    test "living mobs require positive HP and a clear death flag" do
      state = mob_state(100, false)

      assert TargetState.living?(state)
      refute TargetState.corpse?(state)
      refute TargetState.living?(mob_state(0, false))
      refute TargetState.living?(mob_state(100, true))
      refute TargetState.living?(mob_state(0, true))
      refute TargetState.corpse?(mob_state(0, true))
    end
  end

  describe "unsupported snapshots" do
    test "skill units, unknown values, and missing snapshots are neither living nor corpses" do
      skill_unit = struct(Cell, %{cell_id: 1, group_id: 1, map_name: "prontera", x: 1, y: 1})

      for snapshot <- [skill_unit, nil, %{}, :unknown, {:player, 1}] do
        refute TargetState.living?(snapshot)
        refute TargetState.corpse?(snapshot)
      end
    end
  end

  defp mob_state(hp, is_dead) do
    struct(MobState, %{hp: hp, is_dead: is_dead})
  end

  defp player_state(hp, action_state) do
    %PlayerState{stats: %{current_state: %{hp: hp}}, action_state: action_state}
  end
end
