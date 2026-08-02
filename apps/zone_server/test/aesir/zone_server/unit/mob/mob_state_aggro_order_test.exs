defmodule Aesir.ZoneServer.Unit.Mob.MobStateAggroOrderTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Mob.MobState

  defp mob_state do
    %MobState{
      instance_id: 1,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: 0,
      y: 0,
      map_name: "test",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  test "damage_log returns cumulative damage in first-hit order" do
    state =
      mob_state()
      |> MobState.add_aggro(17, 10)
      |> MobState.add_aggro(42, 20)
      |> MobState.add_aggro(17, 5)

    assert MobState.damage_log(state) == [{17, 15}, {42, 20}]
  end

  test "repeated hits do not duplicate the attacker in aggro order" do
    state = mob_state() |> MobState.add_aggro(17, 10) |> MobState.add_aggro(17, 5)

    assert state.aggro_order == [17]
  end

  test "clearing aggro clears the aggro order" do
    state = mob_state() |> MobState.add_aggro(17, 10)

    for reset <- [&MobState.clear_aggro/1, &MobState.set_dead/1] do
      cleared = reset.(state)

      assert cleared.aggro_list == %{}
      assert cleared.aggro_order == []
    end
  end
end
