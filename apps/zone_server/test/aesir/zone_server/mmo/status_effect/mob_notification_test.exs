defmodule Aesir.ZoneServer.Mmo.StatusEffect.MobNotificationTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule Probe do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_mob_notification_probe,
      no_dispel: false,
      no_clear_buff: false,
      permanent: true,
      end_on_start: [:sc_mob_notification_probe]

    @impl true
    def modifiers(%{state: %{wall: true}}, _context), do: %{movement_speed: 10}
    def modifiers(_instance, _context), do: %{}

    @impl true
    def on_tick(_target, _instance, _context), do: :remove

    @impl true
    def on_damage(_target, instance, _info, _context),
      do: {:ok, %{instance | state: Map.put(instance.state, :damaged, true)}}

    @impl true
    def on_movement_intent(_target, %{state: %{wall: true}}, _position, _context), do: :remove

    def on_movement_intent(_target, instance, _position, _context),
      do: {:ok, %{instance | state: %{wall: true}}}
  end

  setup :setup_ets_tables

  setup do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: data.id, amount: 1, respawn_time: 0, spawn_area: nil}
    mob = MobState.new(8801, data, spawn, "prontera", 100, 100)
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    Registry.register_module(Probe)
    %{id: mob.instance_id}
  end

  test "a winning restart publishes its replacement before notifying once", %{id: id} do
    StatusStorage.apply_status(:mob, id, Probe.id(), val1: 1)
    held = StatusStorage.get_status(:mob, id, Probe.id())
    replacement = %{held | val1: 2}

    assert Interpreter.restart_status_if_current(:mob, id, Probe.id(), held, replacement)
    assert StatusStorage.get_status(:mob, id, Probe.id()) == replacement

    assert_received {:"$gen_cast",
                     {:casting, {:status_changed, :sc_mob_notification_probe, :apply}}}

    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}

    refute Interpreter.restart_status_if_current(:mob, id, Probe.id(), held, replacement)
    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
  end

  test "conditional expiry and exact ticks notify only winning removals", %{id: id} do
    for end_status <- [
          fn entry -> Interpreter.expire_status_if_current(:mob, id, Probe.id(), entry) end,
          fn entry ->
            Interpreter.process_tick_if_current(:mob, id, Probe.id(), entry.generation)
          end
        ] do
      StatusStorage.apply_status(:mob, id, Probe.id())
      entry = StatusStorage.get_status(:mob, id, Probe.id())
      end_status.(entry)

      refute StatusStorage.has_status?(:mob, id, Probe.id())

      assert_received {:"$gen_cast",
                       {:casting, {:status_changed, :sc_mob_notification_probe, :removed}}}

      end_status.(entry)
      refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
    end
  end

  test "end-on-start ends the old entry before announcing the replacement", %{id: id} do
    assert :ok = Interpreter.apply_status(:mob, id, Probe.id(), val1: 1)

    assert_received {:"$gen_cast",
                     {:casting, {:status_changed, :sc_mob_notification_probe, :apply}}}

    assert :ok = Interpreter.apply_status(:mob, id, Probe.id(), val1: 2)
    assert %{val1: 2} = StatusStorage.get_status(:mob, id, Probe.id())

    assert_received {:"$gen_cast",
                     {:casting, {:status_changed, :sc_mob_notification_probe, :removed}}}

    assert_received {:"$gen_cast",
                     {:casting, {:status_changed, :sc_mob_notification_probe, :apply}}}

    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
  end

  test "movement changes and removal each notify once after storing", %{id: id} do
    StatusStorage.apply_status(:mob, id, Probe.id())
    position = %{map: "prontera", x: 100, y: 100}

    assert :changed = Interpreter.on_movement_intent(:mob, id, position)
    assert %{state: %{wall: true}} = StatusStorage.get_status(:mob, id, Probe.id())

    assert_received {:"$gen_cast",
                     {:casting, {:status_changed, :sc_mob_notification_probe, :apply}}}

    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}

    assert :changed = Interpreter.on_movement_intent(:mob, id, position)
    refute StatusStorage.has_status?(:mob, id, Probe.id())

    assert_received {:"$gen_cast",
                     {:casting, {:status_changed, :sc_mob_notification_probe, :removed}}}

    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
  end

  @tag game_mode: :pre_renewal
  test "classic Magic Power arms and ends through separate committed notifications", %{id: id} do
    StatusStorage.apply_status(:mob, id, :sc_magicpower, val1: 5)

    assert :changed = Interpreter.on_committed_action(:mob, id, {:skill, 19})
    assert %{state: %{armed: true}} = StatusStorage.get_status(:mob, id, :sc_magicpower)
    assert_received {:"$gen_cast", {:casting, {:status_changed, :sc_magicpower, :armed}}}
    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}

    assert :changed = Interpreter.on_committed_action(:mob, id, {:skill, 19})
    refute StatusStorage.has_status?(:mob, id, :sc_magicpower)
    assert_received {:"$gen_cast", {:casting, {:status_changed, :sc_magicpower, :removed}}}
    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
  end

  test "monster admission rejects scripted and unsupported numeric statuses even when loaded", %{
    id: id
  } do
    for status <- [
          :sc_strfood,
          :sc_atkpotion,
          :sc_inccri,
          :sc_mental_potion,
          :sc_arcane_charge,
          :sc_riding
        ],
        loaded <- [false, true] do
      assert {:error, :ineligible_target} =
               Interpreter.apply_status(:mob, id, status,
                 val1: 1,
                 duration: 60_000,
                 loaded: loaded
               )

      refute StatusStorage.has_status?(:mob, id, status)
    end

    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
  end

  test "claimed absorb removal and damage-driven generation ends notify once", %{id: id} do
    StatusStorage.apply_status(:mob, id, :sc_aeterna)
    hit = %{dmg_type: :physical, is_short: true, element: :neutral, skill_id: 28}

    assert Interpreter.absorb_damage(:mob, id, 50, hit) == 100
    refute StatusStorage.has_status?(:mob, id, :sc_aeterna)
    assert_received {:"$gen_cast", {:casting, {:status_changed, :sc_aeterna, :removed}}}
    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}

    StatusStorage.apply_status(:mob, id, :sc_freeze)
    Interpreter.on_damage(:mob, id, %{damage: 1})
    refute StatusStorage.has_status?(:mob, id, :sc_freeze)
    assert_received {:"$gen_cast", {:casting, {:status_changed, :sc_freeze, :removed}}}
    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
  end

  test "value-only callback writes stay silent", %{id: id} do
    StatusStorage.apply_status(:mob, id, Probe.id())
    Interpreter.on_damage(:mob, id, %{damage: 1})

    assert %{state: %{damaged: true}} = StatusStorage.get_status(:mob, id, Probe.id())
    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
  end

  test "monster admission does not restrict player script bonuses" do
    player =
      PlayerStateFixture.build(%{character_id: 8802, stats: %{combat_stats: %CombatStats{}}})

    :ok = UnitRegistry.register_unit(:player, 8802, PlayerState, player, self())

    assert :ok =
             Interpreter.apply_status(:player, 8802, :sc_strfood,
               val1: 1,
               duration: 60_000,
               loaded: true
             )

    assert StatusStorage.has_status?(:player, 8802, :sc_strfood)
  end

  test "the expiry manager delivers one removal rather than an extra expired cast", %{id: id} do
    StatusStorage.apply_status(:mob, id, Probe.id())
    now = System.monotonic_time(:millisecond)
    StatusStorage.update_status(:mob, id, Probe.id(), &%{&1 | expires_at: now - 1})

    assert {:noreply, _state} =
             StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

    refute StatusStorage.has_status?(:mob, id, Probe.id())

    assert_received {:"$gen_cast",
                     {:casting, {:status_changed, :sc_mob_notification_probe, :removed}}}

    refute_received {:"$gen_cast", {:casting, {:status_changed, _, _}}}
  end
end
