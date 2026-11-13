defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsChainactionTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.Critical
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsChainaction
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  defmodule PriorDouble do
    @moduledoc false
    @doc false
    @spec attack_proc(pos_integer(), map()) :: map()
    def attack_proc(_level, _ctx), do: %{multi_hit: 2, chance: 100}
  end

  setup :set_mimic_private

  test "chainaction_chance_test: revolvers roll 5 percent per level for two divisions" do
    for {level, chance} <- [{1, 5}, {5, 25}, {10, 50}] do
      player = player(%{511 => level}, 13_100)
      attacker = attacker(:revolver, 0)
      target = defender()

      assert %{multi_hit: 2, chance: ^chance} = Passives.attack_procs(player)

      assert {:ok, %{display_divisions: 2, outcome: :hit}} =
               HandedAttack.calculate(player, attacker, target, rng: fn 100 -> chance end)

      assert {:ok, %{display_divisions: 1, outcome: :hit}} =
               HandedAttack.calculate(player, attacker, target, rng: fn 100 -> chance + 1 end)
    end
  end

  test "chainaction_chance_test: a rifle never rolls Chain Action" do
    player = player(%{511 => 10}, 13_150)
    assert Passives.attack_procs(player) == %{}

    assert {:ok, %{display_divisions: 1, outcome: :hit}} =
             HandedAttack.calculate(player, attacker(:rifle, 0), defender(),
               rng: fn _ -> flunk("a rifle must not roll Chain Action") end
             )
  end

  @tag game_mode: :renewal
  test "chainaction_multihit_crit_test: renewal Chain Action can crit" do
    player = player(%{511 => 5}, 13_100)
    attacker = attacker(:revolver, 2_000)

    assert {:ok, %{display_divisions: 2, outcome: :critical}} =
             HandedAttack.calculate(player, attacker, defender(), rng: fn 100 -> 25 end)
  end

  @tag game_mode: :pre_renewal
  test "chainaction_multihit_crit_test: classic Chain Action cannot crit, but its failed proc can" do
    player = player(%{511 => 5}, 13_100)
    attacker = attacker(:revolver, 2_000)

    assert {:ok, %{display_divisions: 2, outcome: :hit}} =
             HandedAttack.calculate(player, attacker, defender(), rng: fn 100 -> 25 end)

    assert {:ok, %{display_divisions: 1, outcome: :critical}} =
             HandedAttack.calculate(player, attacker, defender(), rng: fn 100 -> 26 end)
  end

  @tag game_mode: :renewal
  test "tf_double_renewal_crit_test: renewal Double Attack can crit" do
    player = player(%{48 => 5}, 1201)
    attacker = attacker(:dagger, 2_000)

    assert {:ok, %{display_divisions: 2, outcome: :critical}} =
             HandedAttack.calculate(player, attacker, defender(), rng: fn 100 -> 1 end)
  end

  @tag game_mode: :pre_renewal
  test "tf_double_renewal_crit_test: classic Double Attack cannot crit" do
    player = player(%{48 => 5}, 1201)
    attacker = attacker(:dagger, 2_000)

    assert {:ok, %{display_divisions: 2, outcome: :hit}} =
             HandedAttack.calculate(player, attacker, defender(), rng: fn 100 -> 1 end)
  end

  test "critical permission, not the number of divisions, decides whether a swing can crit" do
    attacker = attacker(:revolver, 2_000)
    target = defender()

    assert Critical.normal_attack?(attacker, target, multi_hit: true, critical_allowed: true)
    refute Critical.normal_attack?(attacker, target, critical_allowed: false)
    refute Critical.normal_attack?(attacker(:revolver, 0), target, critical_allowed: true)
  end

  test "chainaction_proc_after_double_test: an already selected double rolls no Chain Action" do
    player = player(%{48 => 5, 511 => 5}, 13_100)

    stub(Catalog, :passive_module_for, fn
      :tf_double -> {:ok, PriorDouble}
      :gs_chainaction -> {:ok, GsChainaction}
    end)

    assert Passives.attack_procs(player) == %{multi_hit: 2, chance: 100}
    caller = self()

    assert {:ok, %{display_divisions: 2, outcome: :hit}} =
             HandedAttack.calculate(player, attacker(:revolver, 0), defender(),
               rng: fn 100 ->
                 send(caller, :proc_roll)
                 1
               end
             )

    assert_received :proc_roll
    refute_received :proc_roll
  end

  defp player(skills, weapon_id) do
    inventory = [%InventoryItem{nameid: weapon_id, amount: 1, equip: 34, identify: 1}]

    %PlayerState{
      stats: %Stats{
        base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        derived_stats: %DerivedStats{max_hp: 100, max_sp: 100},
        progression: %PlayerProgression{base_level: 50, job_level: 30, learned_skills: skills},
        equipment: Stats.equipment_from_inventory(inventory)
      }
    }
  end

  defp attacker(weapon, critical_rate) do
    CombatTestHelper.create_player_combatant(weapon_type: weapon, dex: 200, luk: 0)
    |> put_in([Access.key!(:combat_stats), :critical_rate], critical_rate)
    |> Map.put(:equip_modifiers, %{perfect_hit: 100})
  end

  defp defender do
    CombatTestHelper.create_mob_combatant(agi: 0, luk: 0, def: 0)
    |> put_in([Access.key!(:combat_stats), :perfect_dodge], 0)
  end
end
