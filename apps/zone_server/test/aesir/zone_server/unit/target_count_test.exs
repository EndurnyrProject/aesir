defmodule Aesir.ZoneServer.Unit.TargetCountTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "saturation loses excess increments, so departures do not reconstruct the current population" do
    victim = mob(5001)
    UnitRegistry.register_unit(:mob, 5001, MobState, victim)

    for id <- 1..256 do
      UnitRegistry.register_unit(:mob, id, MobState, %{mob(id) | attack_target: {:mob, 5001}})
    end

    assert Executor.count_targeting({:mob, 5001}) == 255

    for id <- 1..255, do: UnitRegistry.unregister_unit(:mob, id)
    assert {:ok, _remaining} = UnitRegistry.get_unit(:mob, 256)
    assert Executor.count_targeting({:mob, 5001}) == 0
  end

  test "updates, re-registration, detach and process cleanup count each standing order once" do
    for id <- [1, 2], do: UnitRegistry.register_unit(:mob, id, MobState, mob(id))
    attacker = %{mob(3) | attack_target: {:mob, 1}}
    UnitRegistry.register_unit(:mob, 3, MobState, attacker, self())
    UnitRegistry.register_unit(:mob, 3, MobState, attacker, self())
    assert Executor.count_targeting({:mob, 1}) == 1

    UnitRegistry.update_unit_state(:mob, 3, %{attacker | hp: 99})
    assert Executor.count_targeting({:mob, 1}) == 1
    changed = %{attacker | attack_target: {:mob, 2}}
    UnitRegistry.update_unit_state(:mob, 3, changed)
    assert Executor.count_targeting({:mob, 1}) == 0
    assert Executor.count_targeting({:mob, 2}) == 1

    UnitRegistry.detach_unit(:mob, 3)
    assert Executor.count_targeting({:mob, 2}) == 0
    UnitRegistry.register_unit(:mob, 3, MobState, changed, self())
    UnitRegistry.detach_unit(:mob, 2)
    UnitRegistry.register_unit(:mob, 2, MobState, mob(2))
    assert Executor.count_targeting({:mob, 2}) == 1
    UnitRegistry.cleanup_units_for_pid(self())
    assert Executor.count_targeting({:mob, 2}) == 0
  end

  test "an own-cell movement request publishes the end of a standing attack immediately" do
    :ets.insert(
      EtsTable.table_for(:map_cache),
      {"target_count", MapData.new("target_count", 100, 100)}
    )

    UnitRegistry.register_unit(:mob, 5001, MobState, mob(5001))

    player =
      PlayerState.new(%Character{
        id: 1,
        account_id: 1,
        name: "Counter",
        class: 0,
        sex: "M",
        last_map: "target_count",
        last_x: 10,
        last_y: 10,
        base_level: 1,
        job_level: 1,
        str: 5,
        agi: 5,
        vit: 5,
        int: 5,
        dex: 5,
        luk: 0,
        hp: 100,
        sp: 100
      })

    ref = Process.send_after(self(), :never, 60_000)

    player = %{
      player
      | action_state: :attacking,
        combat_target_id: 5001,
        continuous_attack_timer: ref
    }

    UnitRegistry.register_player(player, self())
    assert Executor.count_targeting({:mob, 5001}) == 1

    assert {:noreply, stopped} =
             MovementHandler.handle_request_move(
               %{game_state: player, connection_pid: self()},
               10,
               10
             )

    assert stopped.game_state.continuous_attack_timer == nil
    assert Executor.count_targeting({:mob, 5001}) == 0
  end

  defp mob(id) do
    struct(MobState, instance_id: id, hp: 100, is_dead: false)
  end
end
