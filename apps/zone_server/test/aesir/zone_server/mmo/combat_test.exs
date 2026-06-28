defmodule Aesir.ZoneServer.Mmo.CombatTest do
  use ExUnit.Case, async: true
  use Mimic
  import ExUnit.CaptureLog

  alias Aesir.Net.DamageDealt
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  defmodule FakeUnit do
    @moduledoc false
    defstruct [:combatant, :stats, :x, :y]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  defp combatant(unit_id, type, opts \\ []) do
    Combatant.new!(%{
      unit_id: unit_id,
      unit_type: type,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 0,
        def: 0,
        hit: Keyword.get(opts, :hit, 200),
        flee: Keyword.get(opts, :flee, 0),
        perfect_dodge: 0
      },
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 5,
      attack_delay_ms: Keyword.get(opts, :attack_delay_ms, 500),
      position: {150, 150},
      map_name: Keyword.get(opts, :map_name, "prontera")
    })
  end

  describe "execute_attack/3 multi-hit procs" do
    setup do
      attacker = combatant(1001, :player)
      target = combatant(2001, :mob)

      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = %FakeUnit{combatant: target, x: 150, y: 150}

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

      %{player_state: player_state, stats: attacker}
    end

    test "applies damage twice and the broadcast packet reflects 2 hits when multi_hit: 2",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)

      expect(MobSession, :apply_damage, 2, fn _pid, damage, _attacker_id ->
        send(test_pid, {:damage_applied, damage})
        :ok
      end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_received {:damage_applied, 50}
      assert_received {:damage_applied, 50}
    end

    test "the broadcast packet carries div 2 and the multi-hit type when multi_hit: 2",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)
      stub(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_received {:packet, %DamageDealt{} = packet}
      assert packet.div == 2
      assert packet.damage == 100
      assert packet.type == 4
    end

    test "applies damage once and packet reflects a single hit when no proc",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      stub(Passives, :attack_procs, fn _player -> %{} end)

      expect(MobSession, :apply_damage, 1, fn _pid, damage, _attacker_id ->
        send(test_pid, {:damage_applied, damage})
        :ok
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_received {:damage_applied, 50}
      refute_received {:damage_applied, _}

      assert_received {:packet, %DamageDealt{} = packet}
      assert packet.div == 1
      assert packet.damage == 50
    end
  end

  describe "execute_attack/3 weapon element" do
    setup do
      # Attacker with a resolved non-neutral weapon element (e.g. a Fire Arrow
      # equipped on a bow), so handle_player_attack_hit builds hit_info with
      # attacker_combatant.weapon.element rather than a hardcoded :neutral.
      attacker = combatant(1001, :player)
      attacker = %{attacker | weapon: %{attacker.weapon | element: :fire}}
      target = combatant(2001, :mob)

      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = %FakeUnit{combatant: target, x: 150, y: 150}

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      stub(Passives, :attack_procs, fn _player -> %{} end)

      %{player_state: player_state, stats: attacker}
    end

    # NOTE: the DamageDealt basic-attack packet carries no element field, and for a
    # mob target hit_info is consumed only by the (identity) player-absorb path, so
    # the element is not observable on the broadcast packet. This test exercises the
    # hit_info construction that reads attacker_combatant.weapon.element, guarding the
    # field access; functional element correctness is covered in damage_calculator_test.
    test "a non-neutral weapon element drives a successful basic attack",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      expect(MobSession, :apply_damage, 1, fn _pid, damage, _attacker_id ->
        send(test_pid, {:damage_applied, damage})
        :ok
      end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_received {:damage_applied, 50}
    end
  end

  describe "execute_attack/3 target validation" do
    setup do
      attacker = combatant(1001, :player)
      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      %{player_state: player_state, stats: attacker}
    end

    test "rejects an attack on a dead mob without applying damage",
         %{player_state: player_state, stats: stats} do
      dead_target = %{is_dead: true, hp: 0, x: 150, y: 150, map_name: "prontera"}
      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, dead_target, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)
      reject(&MobSession.apply_damage/3)

      assert {:error, :target_dead} = Combat.execute_attack(stats, player_state, 2001)
    end

    test "rejects an attack on a target on a different map without applying damage",
         %{player_state: player_state, stats: stats} do
      target = combatant(2001, :mob, map_name: "geffen")
      target_state = %FakeUnit{combatant: target, x: 150, y: 150}
      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "geffen"}} end)
      reject(&MobSession.apply_damage/3)

      assert {:error, :different_map} = Combat.execute_attack(stats, player_state, 2001)
    end
  end

  describe "apply_heal/3" do
    test "broadcasts {:apply_heal, amount, source_id} on the player topic" do
      Phoenix.PubSub.subscribe(Aesir.PubSub, "player:42000")

      Combat.apply_heal(42_000, 500, 1001)

      assert_receive {:apply_heal, 500, 1001}
    end

    test "source_id defaults to nil" do
      Phoenix.PubSub.subscribe(Aesir.PubSub, "player:42001")

      Combat.apply_heal(42_001, 300)

      assert_receive {:apply_heal, 300, nil}
    end
  end

  describe "deal_damage/4" do
    test "returns error for non-existent target" do
      {result, _log} =
        with_log(fn ->
          Combat.deal_damage(99_999, 100, :neutral, :status_effect)
        end)

      assert {:error, :target_not_found} = result
    end

    test "accepts valid parameters" do
      {result, _log} =
        with_log(fn ->
          Combat.deal_damage(1, 100, :fire, :status_effect)
        end)

      assert match?({:error, :target_not_found}, result)
    end
  end
end
