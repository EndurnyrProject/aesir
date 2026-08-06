defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BladeStopTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.AutoAttack
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # MO_FINGEROFFENSIVE (Throw Spirit Sphere), the lowest Root follow-up.
  @throw_spirit_sphere 267
  # MO_BLADESTOP skill id.
  @bladestop 269

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  defmodule LivingUnit do
    @moduledoc false
    defstruct alive: true
    def living?(%__MODULE__{alive: alive}), do: alive
  end

  # A minimal real player registration for the Monk side of a boss test, so its
  # entity info comes from a genuine registry entry (boss_flag false) rather than a
  # blanket stub.
  defmodule FakePlayer do
    @moduledoc false
    defstruct [:char_id]

    def living?(%__MODULE__{}), do: true

    def get_entity_info(%__MODULE__{char_id: id}) do
      %{
        unit_id: id,
        race: :human,
        element: :neutral,
        boss_flag: false,
        size: :medium,
        stats: %{max_hp: 1_000, max_sp: 100}
      }
    end
  end

  # Carries a prebuilt combatant and the genuine player stats AutoAttack threads
  # into attacker_root_level, exercising the real attack_info construction.
  defmodule FakeCombatUnit do
    @moduledoc false
    defstruct [:combatant, :stats]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  describe "establishment via before_weapon_hit" do
    test "an eligible swing is caught pre-Trifecta with both records written before it returns" do
      stub_entity_info()
      monk_id = 5001
      attacker = {:mob, 6001}
      arm_waiting(monk_id, 5)

      assert {:intercept, :blade_stop} =
               Interpreter.before_weapon_hit(
                 :player,
                 monk_id,
                 attack_info(attacker, monk_id, attacker_root_level: 5)
               )

      refute StatusStorage.has_status?(:player, monk_id, :sc_bladestop_wait)

      monk_record = StatusStorage.get_status(:player, monk_id, :sc_bladestop)
      caught_record = StatusStorage.get_status(:mob, 6001, :sc_bladestop)

      assert monk_record.state.peer == {:mob, 6001}
      assert monk_record.state.root_level == 5

      assert caught_record.state.peer == {:player, monk_id}
      assert caught_record.state.root_level == 5

      assert monk_record.state.link_id == caught_record.state.link_id
      assert is_reference(monk_record.state.link_id)
    end

    test "each side stores its own Root level: the Monk's cast level and the attacker's own" do
      stub_entity_info()
      monk_id = 5002
      attacker = {:player, 6002}
      arm_waiting(monk_id, 3)

      assert {:intercept, :blade_stop} =
               Interpreter.before_weapon_hit(
                 :player,
                 monk_id,
                 attack_info(attacker, monk_id, attacker_root_level: 2)
               )

      assert %{state: %{root_level: 3}} =
               StatusStorage.get_status(:player, monk_id, :sc_bladestop)

      assert %{state: %{root_level: 2}} =
               StatusStorage.get_status(:player, 6002, :sc_bladestop)
    end

    test "a non-boss pair lasts ten seconds on both sides" do
      stub_entity_info()
      monk_id = 5003
      arm_waiting(monk_id, 5)

      assert {:intercept, :blade_stop} =
               Interpreter.before_weapon_hit(:player, monk_id, attack_info({:mob, 6003}, monk_id))

      assert pair_duration(:player, monk_id) == 10_000
      assert pair_duration(:mob, 6003) == 10_000
    end

    test "a real boss attacker is caught (immunity bypassed) for two seconds on both sides" do
      monk_id = 5004
      boss_id = 6004
      register_monk(monk_id)
      register_boss_mob(boss_id)
      arm_waiting(monk_id, 5)

      assert {:intercept, :blade_stop} =
               Interpreter.before_weapon_hit(
                 :player,
                 monk_id,
                 attack_info({:mob, boss_id}, monk_id,
                   attacker_boss?: true,
                   attacker_root_level: 5
                 )
               )

      assert StatusStorage.has_status?(:player, monk_id, :sc_bladestop)
      assert StatusStorage.has_status?(:mob, boss_id, :sc_bladestop)
      assert pair_duration(:player, monk_id) == 2_000
      assert pair_duration(:mob, boss_id) == 2_000
    end

    test "a caught player's own record carries their learned Blade Stop level via AutoAttack" do
      stub_entity_info()
      attacker_id = 7001
      monk_id = 7002
      arm_waiting(monk_id, 5)

      # Genuine player progression: the attacker trained Blade Stop to level 4.
      stats = %Stats{
        progression: %PlayerProgression{
          base_level: 99,
          job_id: 24,
          learned_skills: %{@bladestop => 4}
        }
      }

      attacker = %{
        unit_id: attacker_id,
        class: :normal,
        position: {150, 150},
        attack_range: 1,
        weapon: %{element: :neutral}
      }
      target = %{unit_id: monk_id, class: :normal, position: {150, 150}, attack_range: 1}
      player_state = %FakeCombatUnit{combatant: attacker}
      target_state = %FakeCombatUnit{combatant: target}

      stub(TargetResolver, :resolve, fn ^monk_id -> {:ok, self(), target_state, :player} end)
      stub(TargetResolver, :ensure_targetable, fn ^target_state, :player -> :ok end)
      stub(AttackValidator, :validate, fn _attacker, _target, _opts -> :ok end)

      assert :intercepted = AutoAttack.execute_attack(stats, player_state, monk_id)

      assert %{state: %{root_level: 4}} =
               StatusStorage.get_status(:player, attacker_id, :sc_bladestop)

      assert %{state: %{root_level: 5}} =
               StatusStorage.get_status(:player, monk_id, :sc_bladestop)
    end
  end

  describe "eligibility" do
    test "a player attacker is caught regardless of range" do
      stub_entity_info()
      monk_id = 5101
      arm_waiting(monk_id, 5)

      info = attack_info({:player, 6101}, monk_id, distance: 12)
      assert {:intercept, :blade_stop} = Interpreter.before_weapon_hit(:player, monk_id, info)
      assert StatusStorage.has_status?(:player, 6101, :sc_bladestop)
    end

    test "a monster attacker within two cells is caught" do
      stub_entity_info()
      monk_id = 5102
      arm_waiting(monk_id, 5)

      info = attack_info({:mob, 6102}, monk_id, distance: 2)
      assert {:intercept, :blade_stop} = Interpreter.before_weapon_hit(:player, monk_id, info)
      assert StatusStorage.has_status?(:mob, 6102, :sc_bladestop)
    end

    test "a monster attacker beyond two cells leaves the waiting status intact and continues" do
      stub_entity_info()
      monk_id = 5103
      arm_waiting(monk_id, 5)

      info = attack_info({:mob, 6103}, monk_id, distance: 3)
      assert :continue = Interpreter.before_weapon_hit(:player, monk_id, info)

      assert StatusStorage.has_status?(:player, monk_id, :sc_bladestop_wait)
      refute StatusStorage.has_status?(:mob, 6103, :sc_bladestop)
    end
  end

  describe "concurrent claim" do
    test "only one of two swings wins the atomic claim; the loser resolves as a normal hit" do
      stub_entity_info()
      monk_id = 5201
      first = {:mob, 6201}
      second = {:mob, 6202}
      arm_waiting(monk_id, 5)

      assert {:intercept, :blade_stop} =
               Interpreter.before_weapon_hit(:player, monk_id, attack_info(first, monk_id))

      assert :continue =
               Interpreter.before_weapon_hit(:player, monk_id, attack_info(second, monk_id))

      assert StatusStorage.has_status?(:mob, 6201, :sc_bladestop)
      refute StatusStorage.has_status?(:mob, 6202, :sc_bladestop)
    end
  end

  describe "pull-based movement, attack, and skill gates" do
    test "the ready stance immobilizes the armed Monk before any swing lands" do
      monk_id = 5350
      arm_waiting(monk_id, 5)

      refute Interpreter.can_move?(:player, monk_id)
    end

    test "both participants are immobilized and cannot attack" do
      stub_entity_info()
      monk_id = 5301
      arm_waiting(monk_id, 5)

      {:intercept, :blade_stop} =
        Interpreter.before_weapon_hit(:player, monk_id, attack_info({:mob, 6301}, monk_id))

      refute Interpreter.can_move?(:player, monk_id)
      refute Interpreter.can_attack?(:player, monk_id)
      refute Interpreter.can_move?(:mob, 6301)
      refute Interpreter.can_attack?(:mob, 6301)
    end

    test "generic skill use is blocked but the Root follow-up set is exempt" do
      stub_entity_info()
      monk_id = 5302
      arm_waiting(monk_id, 5)

      {:intercept, :blade_stop} =
        Interpreter.before_weapon_hit(:player, monk_id, attack_info({:mob, 6302}, monk_id))

      refute Interpreter.can_use_skill?(:player, monk_id)
      assert Interpreter.can_use_skill?(:player, monk_id, @throw_spirit_sphere)
      refute Interpreter.can_use_skill?(:player, monk_id, 999_999)
    end
  end

  describe "idempotent mutual removal" do
    test "removing one side cascades to the peer and a duplicate removal is a no-op" do
      stub_entity_info()
      monk_id = 5401
      arm_waiting(monk_id, 5)

      {:intercept, :blade_stop} =
        Interpreter.before_weapon_hit(:player, monk_id, attack_info({:mob, 6401}, monk_id))

      Interpreter.remove_status(:player, monk_id, :sc_bladestop)

      refute StatusStorage.has_status?(:player, monk_id, :sc_bladestop)
      refute StatusStorage.has_status?(:mob, 6401, :sc_bladestop)

      # Duplicate removal from either side must not crash and stays a no-op.
      assert :ok = Interpreter.remove_status(:player, monk_id, :sc_bladestop)
      assert :ok = Interpreter.remove_status(:mob, 6401, :sc_bladestop)
    end

    test "removing the caught side also cascades to the Monk" do
      stub_entity_info()
      monk_id = 5402
      arm_waiting(monk_id, 5)

      {:intercept, :blade_stop} =
        Interpreter.before_weapon_hit(:player, monk_id, attack_info({:mob, 6402}, monk_id))

      Interpreter.remove_status(:mob, 6402, :sc_bladestop)

      refute StatusStorage.has_status?(:mob, 6402, :sc_bladestop)
      refute StatusStorage.has_status?(:player, monk_id, :sc_bladestop)
    end
  end

  describe "remove_on_map_change" do
    test "a cross-map warp of a rooted participant unroots both sides" do
      stub_entity_info()
      monk_id = 5450
      arm_waiting(monk_id, 5)

      {:intercept, :blade_stop} =
        Interpreter.before_weapon_hit(:player, monk_id, attack_info({:mob, 6450}, monk_id))

      # The cross-map warp path delegates to this; the flag lives on both records.
      Interpreter.remove_on_map_change(:player, monk_id)

      refute StatusStorage.has_status?(:player, monk_id, :sc_bladestop)
      refute StatusStorage.has_status?(:mob, 6450, :sc_bladestop)
    end
  end

  describe "per-tick convergence" do
    test "keeps the record while the peer record and unit remain intact" do
      stub_entity_info()
      monk_id = 5501
      arm_waiting(monk_id, 5)

      {:intercept, :blade_stop} =
        Interpreter.before_weapon_hit(:player, monk_id, attack_info({:mob, 6501}, monk_id))

      stub_get_unit(alive: true)

      Interpreter.process_tick(:player, monk_id, :sc_bladestop)

      assert StatusStorage.has_status?(:player, monk_id, :sc_bladestop)
    end

    test "unroots the survivor when the peer record was bulk-cleared without callbacks" do
      stub_entity_info()
      monk_id = 5502
      arm_waiting(monk_id, 5)

      {:intercept, :blade_stop} =
        Interpreter.before_weapon_hit(:player, monk_id, attack_info({:mob, 6502}, monk_id))

      # Session teardown clears status storage directly, skipping on_expire.
      StatusStorage.clear_unit_statuses(:mob, 6502)

      Interpreter.process_tick(:player, monk_id, :sc_bladestop)

      refute StatusStorage.has_status?(:player, monk_id, :sc_bladestop)
    end

    test "unroots the survivor when the peer unit is dead or unregistered" do
      stub_entity_info()
      monk_id = 5503
      arm_waiting(monk_id, 5)

      {:intercept, :blade_stop} =
        Interpreter.before_weapon_hit(:player, monk_id, attack_info({:mob, 6503}, monk_id))

      stub_get_unit(alive: false)

      Interpreter.process_tick(:player, monk_id, :sc_bladestop)

      refute StatusStorage.has_status?(:player, monk_id, :sc_bladestop)
      refute StatusStorage.has_status?(:mob, 6503, :sc_bladestop)
    end
  end

  defp arm_waiting(monk_id, level) do
    :ok = StatusStorage.apply_status(:player, monk_id, :sc_bladestop_wait, val1: level)
  end

  defp register_monk(id) do
    :ok = UnitRegistry.register_unit(:player, id, FakePlayer, %FakePlayer{char_id: id}, self())
  end

  defp register_boss_mob(id) do
    mob_data = %MobDefinition{
      id: 1038,
      aegis_name: "test_boss",
      name: "Test Boss",
      level: 50,
      hp: 10_000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :large,
      race: :undead,
      element: {:undead, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      modes: [:boss]
    }

    spawn_ref = %MobSpawn{
      mob: 1038,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 150, y: 150}
    }

    mob = MobState.new(id, mob_data, spawn_ref, "prontera", 150, 150)
    :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, self())
  end

  defp attack_info(attacker, monk_id, opts \\ []) do
    %{
      attacker: attacker,
      target: {:player, monk_id},
      attacker_boss?: Keyword.get(opts, :attacker_boss?, false),
      attacker_root_level: Keyword.get(opts, :attacker_root_level, 0),
      distance: Keyword.get(opts, :distance, 1)
    }
  end

  defp pair_duration(unit_type, unit_id) do
    record = StatusStorage.get_status(unit_type, unit_id, :sc_bladestop)
    record.expires_at - record.started_at
  end

  defp stub_entity_info do
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn _type, id ->
      {:ok,
       %{
         unit_id: id,
         race: :human,
         element: :neutral,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 1_000, max_sp: 100}
       }}
    end)
  end

  defp stub_get_unit(alive: alive) do
    stub(UnitRegistry, :get_unit, fn _type, _id ->
      {:ok, {LivingUnit, %LivingUnit{alive: alive}, self()}}
    end)
  end
end
