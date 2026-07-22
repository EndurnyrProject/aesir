defmodule Aesir.ZoneServer.UnitTest do
  @moduledoc """
  The `living?`/`corpse?` classification contract, dispatched through
  `Unit.living?/1` / `Unit.corpse?/1` to each snapshot's own implementation.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

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

        assert Unit.living?(state)
        refute Unit.corpse?(state)
      end

      for action_state <- @living_actions do
        refute Unit.living?(player_state(0, action_state))
      end
    end

    test "a dead player is non-living and is a corpse only at zero HP" do
      corpse = player_state(0, :dead)

      refute Unit.living?(corpse)
      assert Unit.corpse?(corpse)
      refute Unit.corpse?(player_state(1, :dead))
      refute Unit.corpse?(player_state(-1, :dead))
    end

    test "inconsistent player snapshots fail closed" do
      refute Unit.living?(player_state(0, :dead))
      refute Unit.living?(player_state(-1, :idle))
      refute Unit.living?(player_state(100, :dead))

      refute Unit.living?(%PlayerState{
               action_state: :unknown,
               stats: %{current_state: %{hp: 100}}
             })

      refute Unit.corpse?(player_state(-1, :dead))
      refute Unit.corpse?(player_state(0, :idle))
    end

    test "living mobs require positive HP and a clear death flag" do
      state = mob_state(100, false)

      assert Unit.living?(state)
      refute Unit.corpse?(state)
      refute Unit.living?(mob_state(0, false))
      refute Unit.living?(mob_state(100, true))
      refute Unit.living?(mob_state(0, true))
      refute Unit.corpse?(mob_state(0, true))
    end

    test "skill-unit cells are neither living nor corpses" do
      cell = struct(Cell, %{cell_id: 1, group_id: 1, map_name: "prontera", x: 1, y: 1})

      refute Unit.living?(cell)
      refute Unit.corpse?(cell)
    end
  end

  defp mob_state(hp, is_dead) do
    struct(MobState, %{hp: hp, is_dead: is_dead})
  end

  defp player_state(hp, action_state) do
    %PlayerState{stats: %{current_state: %{hp: hp}}, action_state: action_state}
  end
end
