defmodule Aesir.ZoneServer.Unit.Player.InvincibilityTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @id 8_651
  @first_aid 142
  @fire_bolt 19
  @thunderstorm 21
  @sword_mastery 2
  @teleport 26
  @vending 41

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    state = session_state()
    UnitRegistry.register_unit(:player, @id, PlayerState, state.game_state, self())
    SpatialIndex.add_player(@id, 50, 50, "prontera")
    %{state: state}
  end

  describe "start/1" do
    test "arms the default time, publishes it and restarts in full", %{state: state} do
      started = Invincibility.start(state)
      first = started.game_state.invincible_timer

      assert Process.read_timer(first) in 2_900..3_000
      assert Invincibility.active?({:player, @id})

      restarted = Invincibility.start(started)

      refute Process.read_timer(first)
      assert restarted.game_state.invincible_generation == 2
      assert Process.read_timer(restarted.game_state.invincible_timer) in 2_900..3_000
    end

    test "uses the map's time when it sets one", %{state: state} do
      stub(MapFlags, :invincible_time, fn "prontera" -> 10_000 end)

      started = Invincibility.start(state)

      assert Process.read_timer(started.game_state.invincible_timer) in 9_900..10_000
    end

    test "a zero time starts nothing and leaves a running timer alone", %{state: state} do
      started = Invincibility.start(state)
      stub(Invincibility, :default_time, fn -> 0 end)

      assert Invincibility.start(started) == started
      assert Invincibility.start(state).game_state.invincible_timer == nil
    end
  end

  describe "the end" do
    test "the current deadline ends it and runs the arrival on the player's cell", %{
      state: state
    } do
      started = Invincibility.start(state)
      generation = started.game_state.invincible_generation
      expect(Trigger, :on_appear, fn {:player, @id}, "prontera", 50, 50 -> :ok end)

      assert {:noreply, ended} = Invincibility.handle_info({:expire, generation}, started)

      refute Invincibility.active?({:player, @id})
      assert ended.game_state.invincible_timer == nil
    end

    test "a stale deadline changes nothing", %{state: state} do
      started = Invincibility.start(state)
      reject(&Trigger.on_appear/4)

      assert {:noreply, ^started} = Invincibility.handle_info({:expire, 0}, started)
    end

    test "no arrival runs while the player is between maps", %{state: state} do
      started = Invincibility.start(state)
      warping = put_in(started.game_state.pending_map_load, :warp)
      reject(&Trigger.on_appear/4)

      assert Invincibility.stop(warping).game_state.invincible_timer == nil
    end

    test "stopping without a running timer runs no arrival", %{state: state} do
      reject(&Trigger.on_appear/4)

      assert Invincibility.stop(state) == state
    end
  end

  describe "end_on_request/2" do
    setup %{state: state} do
      stub(Trigger, :on_appear, fn _mover, _map, _x, _y -> :ok end)
      %{started: Invincibility.start(state)}
    end

    test "a walk ends it, even in stone wait with a dialog open", %{started: started} do
      assert ended?(Invincibility.end_on_request(started, :walk))

      stub_body_state(6)
      locked = %{started | interaction_lock: {self(), make_ref(), 1}}
      assert ended?(Invincibility.end_on_request(locked, :walk))
    end

    test "a stunned walk or attack, or a dead walk, keeps it", %{started: started} do
      stub_body_state(3)
      refute ended?(Invincibility.end_on_request(started, :walk))
      refute ended?(Invincibility.end_on_request(started, :attack))

      dead = put_in(started.game_state.action_state, :dead)
      stub_body_state(0)
      refute ended?(Invincibility.end_on_request(dead, :walk))
    end

    test "a skill while sitting or casting keeps it", %{started: started} do
      sitting = put_in(started.game_state.action_state, :sitting)
      refute ended?(Invincibility.end_on_request(sitting, {:skill, @fire_bolt}))

      casting = put_in(started.game_state.casting, %{skill_id: @fire_bolt})
      refute ended?(Invincibility.end_on_request(casting, {:skill, @fire_bolt}))
      refute ended?(Invincibility.end_on_request(casting, {:ground_skill, @thunderstorm}))
    end

    test "a request the skill type, a cooldown or the map refuses keeps it", %{started: started} do
      refute ended?(Invincibility.end_on_request(started, {:skill, @thunderstorm}))
      refute ended?(Invincibility.end_on_request(started, {:skill, @sword_mastery}))
      refute ended?(Invincibility.end_on_request(started, {:ground_skill, @fire_bolt}))

      cooling = put_in(started.game_state.skill_cooldowns, %{@fire_bolt => now() + 60_000})
      refute ended?(Invincibility.end_on_request(cooling, {:skill, @fire_bolt}))

      stub(MapFlags, :get, fn "prontera", :noteleport -> true end)
      refute ended?(Invincibility.end_on_request(started, {:skill, @teleport}))
    end

    test "a vending request ends it unless an NPC stands within three cells", %{
      started: started
    } do
      far = %Placement{map: "prontera", x: 54, y: 54, sprite: 1, name: "far", unique_name: "far"}
      near = %{far | x: 53, y: 47, unique_name: "near"}

      stub(Warps, :for_map, fn _map -> :error end)
      stub(Shops, :for_map, fn _map -> :error end)
      stub(NpcRegistry, :entries, fn -> [{__MODULE__, far}] end)
      assert ended?(Invincibility.end_on_request(started, {:skill, @vending}))

      stub(NpcRegistry, :entries, fn -> [{__MODULE__, far}, {__MODULE__, near}] end)
      refute ended?(Invincibility.end_on_request(started, {:skill, @vending}))
    end

    test "an unlearned skill request still ends it", %{started: started} do
      assert ended?(Invincibility.end_on_request(started, {:skill, @fire_bolt}))
    end

    test "an item skill ends it unless it targets the user", %{started: started} do
      self_item = %{started | pending_item_skill: item_skill(@first_aid)}
      refute ended?(Invincibility.end_on_request(self_item, {:skill, @first_aid}))

      bolt_item = %{started | pending_item_skill: item_skill(@fire_bolt)}
      assert ended?(Invincibility.end_on_request(bolt_item, {:skill, @fire_bolt}))

      ground_item = %{started | pending_item_skill: item_skill(@thunderstorm)}
      assert ended?(Invincibility.end_on_request(ground_item, {:ground_skill, @thunderstorm}))
    end

    test "with storage open only a self skill ends it", %{started: started} do
      storage = put_in(started.game_state.storage, %{})

      refute ended?(Invincibility.end_on_request(storage, {:skill, @fire_bolt}))
      refute ended?(Invincibility.end_on_request(storage, {:ground_skill, @thunderstorm}))
      assert ended?(Invincibility.end_on_request(storage, {:skill, @first_aid}))
    end
  end

  defp ended?(state), do: state.game_state.invincible_timer == nil
  defp now, do: System.monotonic_time(:millisecond)

  defp stub_body_state(body_state) do
    stub(StatusDisplay, :spawn_state, fn :player, @id ->
      %{body_state: body_state, health_state: 0, effect_state: 0, virtue: 0}
    end)
  end

  defp item_skill(skill_id), do: %{skill_id: skill_id, level: 1, keep_requirement?: false}

  defp session_state do
    character = %Character{
      id: @id,
      account_id: 2,
      name: "Knight",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
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

    on_map = %{PlayerState.new(character) | pending_map_load: nil}
    %SessionState{connection_pid: self(), game_state: on_map}
  end
end
