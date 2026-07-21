defmodule Aesir.ZoneServer.Mmo.CombatTest do
  use ExUnit.Case, async: true
  use Mimic
  import ExUnit.CaptureLog

  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.PendingWeaponHit
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  # Equipment breaks are resolved on every confirmed player weapon hit. Default
  # every test to "nothing breaks" so the existing attack assertions are
  # unaffected; the break describe below overrides this with real decisions.
  setup do
    stub(EquipBreak, :resolve, fn _attacker, _target -> [] end)
    :ok
  end

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
      attack_range: Keyword.get(opts, :attack_range, 5),
      attack_delay_ms: Keyword.get(opts, :attack_delay_ms, 500),
      position: Keyword.get(opts, :position, {150, 150}),
      map_name: Keyword.get(opts, :map_name, "prontera")
    })
  end

  defp living_mob_state(combatant, x, y) do
    Mimic.copy(MobState)

    state =
      struct(MobState, %{
        instance_id: combatant.unit_id,
        hp: 100,
        max_hp: 100,
        is_dead: false,
        x: x,
        y: y,
        map_name: combatant.map_name
      })

    stub(MobState, :to_combatant, fn ^state -> combatant end)
    state
  end

  describe "execute_attack/3 multi-hit procs" do
    setup do
      attacker = combatant(1001, :player)
      target = combatant(2001, :mob)

      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

      %{player_state: player_state, stats: attacker, target: target, target_state: target_state}
    end

    test "returns a pending Root offer before Trifecta selection or damage", %{
      player_state: player_state,
      stats: stats
    } do
      stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, attack_info ->
        send(self(), {:root_probe, attack_info})
        {:request_root_offer, %{unit: {:player, 3001}, pid: self()}}
      end)

      reject(&Passives.attack_replacement/1)
      reject(&DamageCalculator.calculate_damage/2)

      assert {:pending, %PendingWeaponHit{} = pending} =
               Combat.execute_attack(stats, player_state, 2001)

      assert pending.target == {:mob, 2001}
      assert pending.continuation == :pre_trifecta
      assert_received {:root_probe, %{attacker: {:player, 1001}, target: {:mob, 2001}}}
    end

    test "resumes a typed pending swing without another Root probe", %{
      player_state: player_state,
      stats: stats
    } do
      pending =
        PendingWeaponHit.new(
          make_ref(),
          {:player, 1001},
          {:mob, 2001},
          %{unit: {:player, 3001}, pid: self()},
          5_000,
          3_000,
          4_200
        )

      reject(&StatusInterpreter.before_weapon_hit/3)
      stub(Passives, :attack_procs, fn _player_state -> %{} end)

      assert :ok = Combat.resume_attack(stats, player_state, pending)
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

    test "a consuming pre-delivery modifier doubles only the first multi-hit packet and HP loss",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)

      expect(StatusInterpreter, :absorb_damage, 2, fn :mob, 2001, 50, _hit_info ->
        case Process.get(:lex_aeterna_hit, 0) do
          0 ->
            Process.put(:lex_aeterna_hit, 1)
            100

          1 ->
            50
        end
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, _attacker_id ->
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

      assert_received {:damage_applied, 100}
      assert_received {:damage_applied, 50}
      assert_received {:packet, %DamageDealt{damage: 100, div: 1}}
      assert_received {:packet, %DamageDealt{damage: 50, div: 1}}
    end

    test "equal modified multi-hits retain their combined packet",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)
      expect(StatusInterpreter, :absorb_damage, 2, fn :mob, 2001, 50, _hit_info -> 100 end)
      stub(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_received {:packet, %DamageDealt{damage: 200, div: 2, type: 4}}
      refute_received {:packet, %DamageDealt{div: 1}}
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

    test "rolls the proc's :chance and delivers the multi-hit when it succeeds",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      # Seed {1,2,3} yields :rand.uniform(100) == 27, at or below a 50% chance.
      :rand.seed(:exsss, {1, 2, 3})
      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2, chance: 50} end)

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

    test "rolls the proc's :chance and delivers a single hit when it fails",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      # Seed {6,7,8} yields :rand.uniform(100) == 87, above a 50% chance.
      :rand.seed(:exsss, {6, 7, 8})
      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2, chance: 50} end)

      expect(MobSession, :apply_damage, 1, fn _pid, damage, _attacker_id ->
        send(test_pid, {:damage_applied, damage})
        :ok
      end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_received {:damage_applied, 50}
      refute_received {:damage_applied, _}
    end

    test "a replacement emits only the skill hit and returns its combo window",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      stub(Passives, :attack_replacement, fn _player ->
        {:skill_attack,
         [
           skill_id: 263,
           skill_level: 5,
           skill_ratio: 200,
           display_hit_count: 3,
           skip_crit: true
         ], :quadruple}
      end)

      reject(&DamageCalculator.calculate_damage/2)

      expect(DamageCalculator, :calculate_damage, fn _attacker, _target, opts ->
        assert opts[:skill_ratio] == 200
        {:ok, %{damage: 75, is_critical: false}}
      end)

      expect(MobSession, :apply_damage, fn _pid, 75, _attacker_id -> :ok end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      assert {:ok, {:combo, :quadruple, {:mob, 2001}, 500}} =
               Combat.execute_attack(stats, player_state, 2001)

      assert_received {:packet, %SkillDamage{skill_id: 263, div: 3, damage: 75}}
      refute_received {:packet, %DamageDealt{}}
    end

    test "a replacement can miss flee without falling back to normal damage",
         %{
           player_state: player_state,
           stats: stats,
           target: target,
           target_state: target_state
         } do
      high_flee_target = %{
        target
        | combat_stats: %{target.combat_stats | flee: 10_000}
      }

      stub(MobState, :to_combatant, fn ^target_state -> high_flee_target end)

      stub(Passives, :attack_replacement, fn _player ->
        {:skill_attack,
         [
           skill_id: 263,
           skill_level: 5,
           skill_ratio: 200,
           display_hit_count: 3,
           skip_crit: true
         ], :quadruple}
      end)

      reject(&DamageCalculator.calculate_damage/2)
      reject(&DamageCalculator.calculate_damage/3)
      reject(&MobSession.apply_damage/3)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      assert {:ok, {:combo, :quadruple, {:mob, 2001}, 500}} =
               Combat.execute_attack(stats, player_state, 2001)

      assert_received {:packet, %SkillDamage{skill_id: 263, div: 3, damage: 0}}
      refute_received {:packet, %DamageDealt{}}
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
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      stub(Passives, :attack_procs, fn _player -> %{} end)

      %{player_state: player_state, stats: attacker}
    end

    # NOTE: the DamageDealt basic-attack packet carries no element field, and since
    # this mob target has no active statuses, the pre-damage absorb hook is a no-op,
    # so the element is not observable on the broadcast packet. This test exercises
    # the hit_info construction that reads attacker_combatant.weapon.element, guarding
    # the field access; functional element correctness is covered in damage_calculator_test.
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
      dead_target =
        struct(MobState, %{is_dead: true, hp: 0, x: 150, y: 150, map_name: "prontera"})

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, dead_target, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)
      reject(&MobSession.apply_damage/3)

      assert {:error, :target_dead} = Combat.execute_attack(stats, player_state, 2001)
    end

    test "rejects an attack on a target on a different map without applying damage",
         %{player_state: player_state, stats: stats} do
      target = combatant(2001, :mob, map_name: "geffen")
      target_state = living_mob_state(target, 150, 150)
      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "geffen"}} end)
      reject(&MobSession.apply_damage/3)

      assert {:error, :different_map} = Combat.execute_attack(stats, player_state, 2001)
    end
  end

  describe "execute_attack/3 equipment breaks" do
    setup do
      attacker = combatant(1001, :player)
      target = combatant(2001, :mob)

      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      stub(Passives, :attack_procs, fn _player -> %{} end)
      stub(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      %{player_state: player_state, stats: attacker, target_state: target_state}
    end

    test "a {:self, :weapon} decision casts {:break_equip, :right_hand} to the attacker session",
         %{player_state: player_state, stats: stats} do
      stub(EquipBreak, :resolve, fn _attacker, _target -> [{:self, :weapon}] end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_received {:"$gen_cast", {:inventory, {:break_equip, :right_hand}}}
      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    test "the break roll fires once per attack even on a multi-hit swing",
         %{player_state: player_state, stats: stats} do
      test_pid = self()

      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)
      stub(EquipBreak, :resolve, fn _attacker, _target -> [{:self, :weapon}] end)

      expect(MobSession, :apply_damage, 2, fn _pid, damage, _attacker_id ->
        send(test_pid, {:damage_applied, damage})
        :ok
      end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_received {:damage_applied, 50}
      assert_received {:damage_applied, 50}
      assert_received {:"$gen_cast", {:inventory, {:break_equip, :right_hand}}}
      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    test "resolve gets a {:mob, target_state} tuple and no decisions means no cast",
         %{player_state: player_state, stats: stats, target_state: target_state} do
      test_pid = self()

      stub(EquipBreak, :resolve, fn _attacker, target ->
        send(test_pid, {:resolve_target, target})
        []
      end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_received {:resolve_target, {:mob, ^target_state}}
      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    test "a {:target, :armor} decision casts {:break_equip, :armor} to the target session, not self",
         %{player_state: player_state, stats: stats, target_state: target_state} do
      test_pid = self()
      target_pid = spawn(fn -> relay_once(test_pid) end)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 ->
        {:ok, {FakeUnit, target_state, target_pid}}
      end)

      stub(EquipBreak, :resolve, fn _attacker, _target -> [{:target, :armor}] end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 2001) == :ok
      end)

      assert_receive {:relayed, {:"$gen_cast", {:inventory, {:break_equip, :armor}}}}
      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    # PvP damage is a no-op today (handle_player_attack_hit returns
    # {:error, :pvp_not_implemented} and applies nothing), so the break roll must
    # be skipped for player targets: resolve is never called and no cast fires.
    test "a player target is not rolled for breaks while PvP is unimplemented",
         %{player_state: player_state, stats: stats} do
      test_pid = self()
      target = combatant(3001, :player)

      target_state = %PlayerState{
        character_id: 3001,
        action_state: :idle,
        x: 150,
        y: 150,
        map_name: "prontera",
        stats: %{current_state: %{hp: 100}}
      }

      Mimic.copy(PlayerState)
      stub(PlayerState, :to_combatant, fn ^target_state -> target end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 3001 -> {:error, :not_found}
        :player, 3001 -> {:ok, {PlayerState, target_state, test_pid}}
      end)

      stub(UnitRegistry, :get_player_pid, fn 3001 -> {:ok, self()} end)

      stub(EquipBreak, :resolve, fn _attacker, resolved_target ->
        send(test_pid, {:resolve_called, resolved_target})
        []
      end)

      capture_log(fn ->
        assert Combat.execute_attack(stats, player_state, 3001) == :ok
      end)

      refute_received {:resolve_called, _}
      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end
  end

  # Forwards a single received message back to the test process so a cast sent to
  # a distinct target pid can be asserted without the test process being the sink.
  defp relay_once(test_pid) do
    receive do
      msg -> send(test_pid, {:relayed, msg})
    end
  end

  describe "apply_heal/4" do
    test "broadcasts {:apply_heal, amount, source_id} on the player topic" do
      Phoenix.PubSub.subscribe(Aesir.PubSub, "player:42000")

      Combat.apply_heal(:player, 42_000, 500, 1001)

      assert_receive {:combat, {:apply_heal, 500, 1001}}
    end

    test "player heal with a nil source_id still broadcasts" do
      Phoenix.PubSub.subscribe(Aesir.PubSub, "player:42001")

      Combat.apply_heal(:player, 42_001, 300, nil)

      assert_receive {:combat, {:apply_heal, 300, nil}}
    end

    test "resolves the target mob's pid via UnitRegistry and heals via MobSession.heal/2" do
      test_pid = self()

      stub(UnitRegistry, :get_unit, fn :mob, 2_001 -> {:ok, {MobState, %{}, test_pid}} end)

      expect(MobSession, :heal, fn pid, amount ->
        send(test_pid, {:healed, pid, amount})
        :ok
      end)

      assert Combat.apply_heal(:mob, 2_001, 500, 1001) == :ok
      assert_receive {:healed, ^test_pid, 500}
    end

    test "a mob that no longer exists is a silent no-op" do
      stub(UnitRegistry, :get_unit, fn :mob, 2_002 -> {:error, :not_found} end)
      reject(&MobSession.heal/2)

      assert Combat.apply_heal(:mob, 2_002, 500, 1001) == :ok
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

  describe "execute_skill_attack/3 hit_count" do
    setup do
      attacker = combatant(1001, :player)
      target = combatant(2001, :mob)
      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d, opts ->
        assert opts[:skill_id] == 7
        {:ok, %{damage: 50, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

      %{player_state: player_state}
    end

    test "delivers damage hit_count times against the target", %{player_state: player_state} do
      expect(MobSession, :apply_damage, 2, fn _pid, _damage, _attacker_id -> :ok end)

      assert :ok =
               Combat.execute_skill_attack(player_state, 2001,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100,
                 hit_count: 2
               )
    end

    test "defaults to a single hit when hit_count is absent", %{player_state: player_state} do
      expect(MobSession, :apply_damage, 1, fn _pid, _damage, _attacker_id -> :ok end)

      assert :ok =
               Combat.execute_skill_attack(player_state, 2001,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100
               )
    end

    test "hit_count: 1 is identical to absent hit_count", %{player_state: player_state} do
      expect(MobSession, :apply_damage, 1, fn _pid, _damage, _attacker_id -> :ok end)

      assert :ok =
               Combat.execute_skill_attack(player_state, 2001,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100,
                 hit_count: 1
               )
    end
  end

  describe "execute_skill_attack/3 hit result" do
    setup do
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      :ok
    end

    test "report_hit: true reports a connected hit and applies damage" do
      attacker = combatant(1001, :player, hit: 200)
      target = combatant(2001, :mob, flee: 0)
      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d, _opts ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      expect(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      assert {:ok, %{hit?: true}} =
               Combat.execute_skill_attack(player_state, 2001,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100,
                 report_hit: true
               )
    end

    test "report_hit: true reports a dodged hit and applies no damage" do
      attacker = combatant(1001, :player, hit: 0)
      target = combatant(2001, :mob, flee: 300)
      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      reject(&DamageCalculator.calculate_damage/3)
      reject(&MobSession.apply_damage/3)

      assert {:ok, %{hit?: false}} =
               Combat.execute_skill_attack(player_state, 2001,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100,
                 report_hit: true
               )
    end

    test "without report_hit a connected hit still returns plain :ok" do
      attacker = combatant(1001, :player, hit: 200)
      target = combatant(2001, :mob, flee: 0)
      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d, _opts ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      expect(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      assert :ok =
               Combat.execute_skill_attack(player_state, 2001,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100
               )
    end
  end

  describe "execute_skill_attack/3 projectile line of sight" do
    test "a ranged physical skill blocked by a projectile-blocking cell fails" do
      Mimic.copy(Cell)
      stub(Cell, :blocks_projectiles?, fn "prontera", x, y -> {x, y} == {150, 151} end)

      attacker = combatant(1001, :player, attack_range: 5, position: {150, 150})
      target = combatant(2001, :mob, position: {150, 153})
      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = living_mob_state(target, 150, 153)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 153, "prontera"}} end)
      reject(&MobSession.apply_damage/3)

      assert {:error, :projectile_blocked} =
               Combat.execute_skill_attack(player_state, 2001,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100
               )
    end

    test "a melee physical skill on an adjacent target ignores projectile blocking" do
      Mimic.copy(Cell)
      stub(Cell, :blocks_projectiles?, fn _map, _x, _y -> true end)

      attacker = combatant(1001, :player, attack_range: 1, position: {150, 150})
      target = combatant(2001, :mob, position: {151, 150})
      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = living_mob_state(target, 151, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {151, 150, "prontera"}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d, _opts ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      stub(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      assert :ok =
               Combat.execute_skill_attack(player_state, 2001,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100
               )
    end
  end

  describe "execute_mob_attack/2 projectile line of sight" do
    setup do
      target = combatant(2001, :player, position: {150, 153})
      target_state = %FakeUnit{combatant: target, stats: target, x: 150, y: 153}

      stub(UnitRegistry, :get_player_pid, fn 2001 -> {:ok, self()} end)

      stub(UnitRegistry, :get_unit, fn :player, 2001 ->
        {:ok, {FakeUnit, target_state, self()}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      :ok
    end

    test "a ranged mob attack blocked by a projectile-blocking cell fails" do
      Mimic.copy(Cell)
      stub(Cell, :blocks_projectiles?, fn "prontera", x, y -> {x, y} == {150, 151} end)

      mob = combatant(3001, :mob, attack_range: 5, position: {150, 150})
      mob_state = %FakeUnit{combatant: mob, x: 150, y: 150}

      reject(&PlayerSession.apply_damage/3)

      assert {:error, :projectile_blocked} = Combat.execute_mob_attack(mob_state, 2001)
    end

    test "a melee mob attack on an adjacent target ignores projectile blocking" do
      Mimic.copy(Cell)
      stub(Cell, :blocks_projectiles?, fn _map, _x, _y -> true end)

      adjacent = combatant(2001, :player, position: {151, 150})
      adjacent_state = %FakeUnit{combatant: adjacent, stats: adjacent, x: 151, y: 150}

      stub(UnitRegistry, :get_unit, fn :player, 2001 ->
        {:ok, {FakeUnit, adjacent_state, self()}}
      end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d ->
        {:ok, %{damage: 10, is_critical: false}}
      end)

      stub(PlayerSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      mob = combatant(3001, :mob, attack_range: 1, position: {150, 150})
      mob_state = %FakeUnit{combatant: mob, x: 150, y: 150}

      assert :ok = Combat.execute_mob_attack(mob_state, 2001)
    end
  end

  describe "execute_mob_attack/2 pre-damage absorption" do
    setup do
      target = combatant(2001, :player, position: {151, 150})
      target_state = %FakeUnit{combatant: target, stats: target, x: 151, y: 150}

      stub(UnitRegistry, :get_player_pid, fn 2001 -> {:ok, self()} end)

      stub(UnitRegistry, :get_unit, fn :player, 2001 ->
        {:ok, {FakeUnit, target_state, self()}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d ->
        {:ok, %{damage: 10, is_critical: false}}
      end)

      :ok
    end

    test "mob melee runs through the absorb_damage hook before HP loss" do
      test_pid = self()

      expect(StatusInterpreter, :absorb_damage, fn :player, 2001, 10, hit_info ->
        send(test_pid, {:hit_info, hit_info})
        3
      end)

      expect(PlayerSession, :apply_damage, fn _pid, damage, 3001 ->
        send(test_pid, {:applied, damage})
        :ok
      end)

      mob = combatant(3001, :mob, attack_range: 1, position: {150, 150})
      mob_state = %FakeUnit{combatant: mob, x: 150, y: 150}

      assert :ok = Combat.execute_mob_attack(mob_state, 2001)

      assert_received {:applied, 3}

      assert_received {:hit_info,
                       %{
                         dmg_type: :physical,
                         is_short: true,
                         skill_id: nil,
                         from_caster?: true
                       }}
    end

    test "a ranged mob attack is marked long-range in hit_info" do
      test_pid = self()

      expect(StatusInterpreter, :absorb_damage, fn :player, 2001, 10, hit_info ->
        send(test_pid, {:hit_info, hit_info})
        10
      end)

      stub(PlayerSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      mob = combatant(3001, :mob, attack_range: 5, position: {150, 150})
      mob_state = %FakeUnit{combatant: mob, x: 150, y: 150}

      assert :ok = Combat.execute_mob_attack(mob_state, 2001)

      assert_received {:hit_info, %{is_short: false, dmg_type: :physical}}
    end
  end

  describe "on-hit equipment status infliction wiring" do
    test "a landed player auto-attack rolls the attacker's bAddEff against the mob" do
      test_pid = self()

      attacker =
        1001
        |> combatant(:player)
        |> Map.put(:equip_modifiers, %{{:add_eff, :sc_stun} => 10_000})

      target = combatant(2001, :mob)
      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)
      stub(Passives, :attack_procs, fn _ -> %{} end)
      stub(MobSession, :apply_damage, fn _pid, _d, _a -> :ok end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_stun, params ->
        send(test_pid, {:on_hit, params})
        :ok
      end)

      capture_log(fn ->
        assert Combat.execute_attack(attacker, player_state, 2001) == :ok
      end)

      assert_received {:on_hit, params}
      assert params[:caster_id] == 1001
      assert params[:source_type] == :player
    end

    test "a landed mob attack rolls the player's bAddEffWhenHit back against the mob" do
      test_pid = self()

      target =
        2001
        |> combatant(:player, position: {151, 150})
        |> Map.put(:equip_modifiers, %{{:add_eff_when_hit, :sc_freeze} => 10_000})

      target_state = %FakeUnit{combatant: target, stats: target, x: 151, y: 150}

      stub(UnitRegistry, :get_player_pid, fn 2001 -> {:ok, self()} end)

      stub(UnitRegistry, :get_unit, fn :player, 2001 ->
        {:ok, {FakeUnit, target_state, self()}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)
      stub(StatusInterpreter, :absorb_damage, fn :player, 2001, dmg, _hit_info -> dmg end)
      stub(PlayerSession, :apply_damage, fn _pid, _d, _a -> :ok end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d ->
        {:ok, %{damage: 10, is_critical: false}}
      end)

      expect(StatusInterpreter, :apply_status, fn :mob, 3001, :sc_freeze, params ->
        send(test_pid, {:on_hit, params})
        :ok
      end)

      mob = combatant(3001, :mob, attack_range: 1, position: {150, 150})
      mob_state = %FakeUnit{combatant: mob, x: 150, y: 150}

      assert :ok = Combat.execute_mob_attack(mob_state, 2001)

      assert_received {:on_hit, params}
      assert params[:caster_id] == 2001
      assert params[:source_type] == :player
    end
  end
end
