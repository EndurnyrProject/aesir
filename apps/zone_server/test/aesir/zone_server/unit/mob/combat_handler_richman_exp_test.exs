defmodule Aesir.ZoneServer.Unit.Mob.CombatHandlerRichmanExpTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 42
  @mob_id 7_001

  setup :verify_on_exit!
  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _instance_id, _attacker_id -> :ok end)
    register_player(@player_id)
    Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{@player_id}")
    :ok
  end

  describe "pre-renewal" do
    setup do
      stub(GameMode, :mode, fn -> :pre_renewal end)
      :ok
    end

    test "killing a mob under Richman grants 25 + 11 * level percent more base and job EXP" do
      StatusStorage.apply_status(:mob, @mob_id, :sc_richmankim, val1: 5)

      kill_mob()

      assert_receive {:progression, {:mob_kill_exp, 1_800, 900, :formless, :normal}}
    end

    test "the bonus stacks on top of the server EXP rates" do
      stub(Config, :base_exp_rate, fn -> 200 end)
      stub(Config, :job_exp_rate, fn -> 300 end)

      StatusStorage.apply_status(:mob, @mob_id, :sc_richmankim, val1: 1)

      kill_mob()

      assert_receive {:progression, {:mob_kill_exp, 2_720, 2_040, :formless, :normal}}
    end

    test "a mob without Richman grants its unmodified EXP" do
      kill_mob()

      assert_receive {:progression, {:mob_kill_exp, 1_000, 500, :formless, :normal}}
    end

    test "Richman on the killer does not modify the mob's kill EXP" do
      StatusStorage.apply_status(:player, @player_id, :sc_richmankim, val1: 5)

      kill_mob()

      assert_receive {:progression, {:mob_kill_exp, 1_000, 500, :formless, :normal}}
    end
  end

  describe "renewal" do
    setup do
      stub(GameMode, :mode, fn -> :renewal end)
      :ok
    end

    test "Richman on the killed mob does not change the shared kill EXP" do
      StatusStorage.apply_status(:mob, @mob_id, :sc_richmankim, val1: 5)

      kill_mob()

      assert_receive {:progression, {:mob_kill_exp, 1_000, 500, :formless, :normal}}
    end
  end

  defp kill_mob do
    {:noreply, killed} =
      CombatHandler.handle_apply_damage(1_000, {:player, @player_id}, mob_state())

    assert killed.is_dead
  end

  defp register_player(character_id) do
    character = %Character{
      id: character_id,
      account_id: character_id,
      name: "Killer",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }

    UnitRegistry.register_player(PlayerState.new(character), self())
  end

  defp mob_state do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1_000,
      sp: 0,
      base_exp: 1_000,
      job_exp: 500,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1_200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(@mob_id, mob_data, spawn_ref, "prontera", 100, 100)
  end
end
