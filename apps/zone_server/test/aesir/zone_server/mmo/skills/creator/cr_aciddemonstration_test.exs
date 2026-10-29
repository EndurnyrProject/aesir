defmodule Aesir.ZoneServer.Mmo.Skills.Creator.CrAciddemonstrationTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Creator.CrAciddemonstration
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 49_001
  @player_target 49_002
  @mob_target 49_003

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    {:ok, definition} = Catalog.by_id(490)
    victim = player(@player_target, vit: 20)
    :ok = UnitRegistry.register_player(victim, self())
    {:ok, definition: definition, victim: victim, mob: monster(@mob_target, vit: 42, int: 17)}
  end

  describe "renewal" do
    @describetag game_mode: :renewal

    test "ratio is 200 per level plus the caster's INT and the target's VIT, halved on a player",
         %{definition: definition, victim: victim, mob: mob} do
      opts = attack(:execute_skill_attack, player(@caster_id, int: 30), definition, 10)

      assert {:target, ratio} = opts[:skill_ratio]
      assert ratio.(MobState.to_combatant(mob)) == 2_000 + 30 + 42
      assert ratio.(PlayerState.to_combatant(victim)) == div(2_000 + 30 + 20, 2)
      assert opts[:hit_divisions] == 10
      refute Keyword.has_key?(opts, :element)
    end

    test "a monster casts it with its own INT", %{definition: definition, mob: mob} do
      caster = monster(49_004, vit: 1, int: 55)
      opts = attack(:execute_skill_attack, caster, definition, 1)

      {:target, ratio} = opts[:skill_ratio]
      assert ratio.(MobState.to_combatant(mob)) == 200 + caster.calculated.int + 42
    end
  end

  describe "pre-renewal" do
    @describetag game_mode: :pre_renewal

    test "base is 7 * VIT * INT^2 / (10 * (VIT + INT)), halved on a player, in level hits",
         %{definition: definition, victim: victim, mob: mob} do
      opts = attack(:execute_misc_attack, player(@caster_id, int: 30), definition, 10)

      assert {:target, base} = opts[:base_damage]
      # 7 * 42 * 900 / 720 = 367; 7 * 20 * 900 / 500 = 252, halved 126.
      assert base.(MobState.to_combatant(mob)) == 367
      assert base.(PlayerState.to_combatant(victim)) == 126
      assert opts[:element] == :neutral
      assert opts[:hit_divisions] == 10
    end

    test "base is 0 when the target's VIT and the caster's INT are both 0", %{
      definition: definition
    } do
      opts = attack(:execute_misc_attack, player(@caster_id, int: 0), definition, 1)
      {:target, base} = opts[:base_damage]
      assert base.(MobState.to_combatant(monster(49_005, vit: 0, int: 1))) == 0
    end
  end

  describe "equipment break" do
    test "a connected hit on a player rolls weapon then armor at level percent", %{
      definition: definition,
      victim: victim
    } do
      hit({:ok, %{hit?: true, blocked?: false, connected?: true, target_survives?: true}})
      stub(TargetResolver, :resolve, fn @player_target -> {:ok, self(), victim, :player} end)

      expect(EquipBreak, :resolve_slot, 2, fn 1_000,
                                              {:player, @player_target, _stats},
                                              slot,
                                              [] ->
        [{:target, slot}]
      end)

      test_pid = self()
      expect(PlayerSession, :break_equip, 2, fn _pid, slot -> send(test_pid, {:broke, slot}) end)

      assert {:ok, _caster} =
               CrAciddemonstration.cast(
                 player(@caster_id),
                 {:unit, @player_target},
                 10,
                 definition
               )

      assert_received {:broke, :weapon}
      assert_received {:broke, :armor}
    end

    test "coated pieces never break", %{
      definition: definition,
      victim: victim
    } do
      victim = put_in(victim.stats.equipment, %Equipment{right_hand: 1101, armor: 2301})
      hit({:ok, %{hit?: true, blocked?: false, connected?: true, target_survives?: true}})
      stub(TargetResolver, :resolve, fn @player_target -> {:ok, self(), victim, :player} end)
      :ok = StatusStorage.apply_status(:player, @player_target, :sc_cp_weapon)
      :ok = StatusStorage.apply_status(:player, @player_target, :sc_cp_armor)

      stub(EquipBreak, :resolve_slot, fn rate, target, slot, _opts ->
        call_original(EquipBreak, :resolve_slot, [rate, target, slot, [rng: fn _ -> 1 end]])
      end)

      reject(&PlayerSession.break_equip/2)

      assert {:ok, _caster} =
               CrAciddemonstration.cast(
                 player(@caster_id),
                 {:unit, @player_target},
                 10,
                 definition
               )
    end

    test "a miss, a dead target or a monster target breaks nothing", %{
      definition: definition,
      victim: victim,
      mob: mob
    } do
      reject(&PlayerSession.break_equip/2)
      reject(&EquipBreak.resolve_slot/4)

      stub(TargetResolver, :resolve, fn
        @player_target -> {:ok, self(), victim, :player}
        @mob_target -> {:ok, self(), mob, :mob}
      end)

      for report <- [
            %{hit?: false, blocked?: false, connected?: false, target_survives?: true},
            %{hit?: true, blocked?: false, connected?: true, target_survives?: false}
          ] do
        hit({:ok, report})

        assert {:ok, _caster} =
                 CrAciddemonstration.cast(
                   player(@caster_id),
                   {:unit, @player_target},
                   10,
                   definition
                 )
      end

      hit({:ok, %{hit?: true, blocked?: false, connected?: true, target_survives?: true}})

      assert {:ok, _caster} =
               CrAciddemonstration.cast(player(@caster_id), {:unit, @mob_target}, 10, definition)
    end
  end

  defp attack(function, caster, definition, level) do
    test_pid = self()

    stub(Combat, function, fn _caster, _target, opts ->
      send(test_pid, {:opts, opts})
      {:ok, %{hit?: false, blocked?: false, connected?: false, target_survives?: true}}
    end)

    assert {:ok, _caster} =
             CrAciddemonstration.cast(caster, {:unit, @mob_target}, level, definition)

    assert_received {:opts, opts}
    opts
  end

  defp hit(result) do
    stub(Combat, :execute_skill_attack, fn _caster, _target, _opts -> result end)
    stub(Combat, :execute_misc_attack, fn _caster, _target, _opts -> result end)
  end

  defp player(id, opts \\ []) do
    %Character{
      id: id,
      account_id: id,
      name: "Creator#{id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 4_019,
      sex: "M",
      base_level: 99,
      vit: Keyword.get(opts, :vit, 1),
      int: Keyword.get(opts, :int, 1)
    }
    |> PlayerState.new()
  end

  defp monster(instance_id, stats) do
    definition =
      Aesir.TestMob.definition(
        stats: %{str: 1, agi: 1, vit: stats[:vit], int: stats[:int], dex: 1, luk: 1}
      )

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 0,
      spawn_area: %MobSpawn.SpawnArea{x: 0, y: 0}
    }

    MobState.new(instance_id, definition, spawn, "prontera", 0, 0)
  end
end
