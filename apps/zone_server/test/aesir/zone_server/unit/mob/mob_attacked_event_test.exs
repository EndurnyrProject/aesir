defmodule Aesir.ZoneServer.Unit.Mob.MobAttackedEventTest do
  @moduledoc """
  Verifies which delivered hits schedule a mob's attacked event, after which
  walk delay, and when the event is a "norm" one.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.AttackedEvent
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(SpatialIndex, :get_unit_position, fn :player, 42 -> {:ok, {101, 100, "prontera"}} end)
    :ok
  end

  @attacker {:player, 42}
  @hit %{dmg_type: :physical, is_short: true, skill_id: nil, div: 1}

  describe "walk_delay/3" do
    test "is the damage motion plus 200 ms per extra division, more than 10 counting as 2" do
      assert AttackedEvent.walk_delay(50, 1, 300) == 300
      assert AttackedEvent.walk_delay(50, 3, 300) == 700
      assert AttackedEvent.walk_delay(50, 12, 300) == 500
    end

    test "is 0 below 1 damage or without divisions, else at least 1" do
      assert AttackedEvent.walk_delay(0, 3, 300) == 0
      assert AttackedEvent.walk_delay(50, 0, 300) == 0
      assert AttackedEvent.walk_delay(50, 1, 0) == 1
    end
  end

  describe "a delivered hit" do
    test "that landed schedules the attacked event after its walk delay" do
      hit(100, Map.put(@hit, :div, 2))

      refute_receive {:ai, {:attacked, _, _}}, 400
      assert_receive {:ai, {:attacked, @attacker, false}}, 300
    end

    test "that missed, was blocked or is a status tick schedules nothing" do
      hit(0, @hit)
      hit(0, Map.put(@hit, :blocked?, true))
      hit(30, %{status_tick?: true, div: 1})
      hit(30, Map.delete(@hit, :div))

      refute_receive {:ai, {:attacked, _, _}}, 400
    end

    test "dealt as fixed damage without divisions schedules at once" do
      hit(500, %{dmg_type: :misc, skill_id: 489, walk_delay?: false, div: 0})

      assert_receive {:ai, {:attacked, @attacker, false}}, 50
    end

    test "returned by a reflect connects even for no damage" do
      hit(0, %{reflected: true, div: 1})

      assert_receive {:ai, {:attacked, @attacker, false}}, 50
    end

    test "dealt connected for no damage schedules at once and logs its attacker" do
      {:noreply, state} =
        hit(0, %{skill_id: nil, div: 1, connected?: true, pre_delivery_prepared?: true})

      assert_receive {:ai, {:attacked, @attacker, false}}, 50
      assert %{damage: 0} = state.typed_aggro_list[@attacker]
      assert state.hp == 1000
      assert is_integer(state.last_damage_time)
    end

    test "a normal attack on a mob attacking someone else from within its range + 1 is norm" do
      attacking = %{mob_state() | skill_state: :berserk, target_ref: {:player, 7}}
      normal = Map.put(@hit, :weapon_attack?, true)

      hit(10, normal, attacking)
      hit(10, Map.put(@hit, :basic_attack?, true), attacking)
      hit(10, normal, %{attacking | skill_state: :angry})

      assert_receive {:ai, {:attacked, @attacker, true}}, 400
      assert_receive {:ai, {:attacked, @attacker, false}}, 400
      assert_receive {:ai, {:attacked, @attacker, false}}, 400
    end
  end

  test "an equipment coma hit carries its attacked event through the coma path" do
    {:noreply, _state} =
      MobSession.handle_cast(
        {:combat, {:apply_coma, @attacker, Map.merge(@hit, %{coma?: true, hit_damage: 50})}},
        mob_state()
      )

    assert_receive {:ai, {:attacked, @attacker, false}}, 400
  end

  test "a coma on a missed or blocked hit leaves 1 HP but schedules nothing" do
    for metadata <- [
          Map.merge(@hit, %{coma?: true, hit_damage: 0}),
          Map.merge(@hit, %{coma?: true, hit_damage: 0, blocked?: true})
        ] do
      {:noreply, state} =
        MobSession.handle_cast({:combat, {:apply_coma, @attacker, metadata}}, mob_state())

      assert state.hp == 1
      assert state.sp == 1
    end

    refute_receive {:ai, {:attacked, _, _}}, 400
  end

  test "a coma on a connected hit of no damage schedules the event at once" do
    {:noreply, _state} =
      MobSession.handle_cast(
        {:combat,
         {:apply_coma, @attacker,
          %{connected?: true, coma?: true, hit_damage: 0, div: 1, skill_id: nil}}},
        mob_state()
      )

    assert_receive {:ai, {:attacked, @attacker, false}}, 50
  end

  test "a status-started coma schedules nothing" do
    {:noreply, _state} =
      MobSession.handle_cast({:combat, {:apply_coma, @attacker, %{}}}, mob_state())

    refute_receive {:ai, {:attacked, _, _}}, 400
  end

  defp hit(damage, metadata, state \\ mob_state()) do
    {:noreply, _state} =
      MobSession.handle_cast({:combat, {:apply_damage, damage, @attacker, metadata}}, state)
  end

  defp mob_state do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      class: Aesir.ZoneServer.Mmo.MobManagement.MobMode.class([:can_move, :can_attack]),
      modes: [:can_move, :can_attack]
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
  end
end
