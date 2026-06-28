defmodule Aesir.ZoneServer.Mmo.Skill.PassivesTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  # Real equip.yml ids whose subtype matches the weapon atoms under test.
  @weapon_ids %{one_handed_sword: 1101, bow: 1701}
  @both_hand 34
  @right_hand 2

  defmodule FleePassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_001,
      name: :test_flee_passive,
      display_name: "Test Flee Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def flee_bonus(level, _ctx), do: 4 * level
  end

  defmodule MultiHitPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_002,
      name: :test_multi_hit_passive,
      display_name: "Test Multi Hit Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def attack_proc(_level, _ctx), do: %{multi_hit: 2}
  end

  defmodule HigherMultiHitPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_003,
      name: :test_higher_multi_hit_passive,
      display_name: "Test Higher Multi Hit Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def attack_proc(_level, _ctx), do: %{multi_hit: 3}
  end

  defp build_player(learned_skills, weapon_atom) do
    equip = if weapon_atom == :bow, do: @both_hand, else: @right_hand
    nameid = Map.fetch!(@weapon_ids, weapon_atom)
    weapon = %InventoryItem{nameid: nameid, amount: 1, equip: equip, identify: 1}

    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 10, int: 10, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 100},
      progression: %PlayerProgression{
        base_level: 50,
        job_level: 30,
        learned_skills: learned_skills
      },
      equipment: Stats.equipment_from_inventory([weapon])
    }

    %PlayerState{stats: stats}
  end

  describe "atk_bonus/1" do
    test "SM_SWORD level 5 with a one-handed sword grants 20 ATK" do
      player = build_player(%{2 => 5}, :one_handed_sword)
      assert Passives.atk_bonus(player) == 20
    end

    test "SM_SWORD level 5 with a bow grants 0 ATK" do
      player = build_player(%{2 => 5}, :bow)
      assert Passives.atk_bonus(player) == 0
    end
  end

  describe "flee_bonus/1" do
    test "returns 0 when no flee passive is learned" do
      player = build_player(%{2 => 5}, :one_handed_sword)
      assert Passives.flee_bonus(player) == 0
    end

    test "sums the flee bonus contributed by a learned flee passive" do
      stub(Catalog, :by_id, fn 9_900_001 -> {:ok, FleePassive.definition()} end)
      stub(Catalog, :passive_module_for, fn :test_flee_passive -> {:ok, FleePassive} end)

      player = build_player(%{9_900_001 => 5}, :one_handed_sword)

      assert Passives.flee_bonus(player) == 20
    end
  end

  describe "dex_bonus/1, hit_bonus/1 and range_bonus/1" do
    test "all return 0 when no passive contributes the channel" do
      player = build_player(%{2 => 5}, :one_handed_sword)

      assert Passives.dex_bonus(player) == 0
      assert Passives.hit_bonus(player) == 0
      assert Passives.range_bonus(player) == 0
    end

    test "return 0 when no skills are learned" do
      player = build_player(%{}, :bow)

      assert Passives.dex_bonus(player) == 0
      assert Passives.hit_bonus(player) == 0
      assert Passives.range_bonus(player) == 0
    end
  end

  describe "attack_procs/1" do
    test "returns an empty map when no passive procs on attack" do
      player = build_player(%{2 => 5}, :one_handed_sword)
      assert Passives.attack_procs(player) == %{}
    end

    test "merges :multi_hit from a learned proc passive" do
      stub(Catalog, :by_id, fn 9_900_002 -> {:ok, MultiHitPassive.definition()} end)
      stub(Catalog, :passive_module_for, fn :test_multi_hit_passive -> {:ok, MultiHitPassive} end)

      player = build_player(%{9_900_002 => 5}, :one_handed_sword)

      assert Passives.attack_procs(player) == %{multi_hit: 2}
    end

    test "keeps the max :multi_hit across learned proc passives" do
      stub(Catalog, :by_id, fn
        9_900_002 -> {:ok, MultiHitPassive.definition()}
        9_900_003 -> {:ok, HigherMultiHitPassive.definition()}
      end)

      stub(Catalog, :passive_module_for, fn
        :test_multi_hit_passive -> {:ok, MultiHitPassive}
        :test_higher_multi_hit_passive -> {:ok, HigherMultiHitPassive}
      end)

      player = build_player(%{9_900_002 => 5, 9_900_003 => 5}, :one_handed_sword)

      assert Passives.attack_procs(player) == %{multi_hit: 3}
    end
  end

  describe "regen/1" do
    test "merges flat skill HP regen and the moving flag" do
      player = build_player(%{4 => 5, 144 => 1}, :one_handed_sword)

      regen = Passives.regen(player)

      assert regen.skill_hp_regen == 35
      assert regen.allow_while_moving == true
      assert regen.skill_sp_regen == 0
    end

    test "returns all keys defaulted when no regen passives are learned" do
      player = build_player(%{2 => 5}, :one_handed_sword)

      assert Passives.regen(player) ==
               %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: false}
    end
  end

  describe "rider_for/3" do
    test "SM_FATALBLOW yields a stun rider for Bash above level 5" do
      player = build_player(%{145 => 1}, :one_handed_sword)

      assert [{:apply_status, :sc_stun, _opts}] = Passives.rider_for(:sm_bash, 6, player)
    end

    test "SM_FATALBLOW yields no rider for Bash at level 5" do
      player = build_player(%{145 => 1}, :one_handed_sword)

      assert Passives.rider_for(:sm_bash, 5, player) == []
    end
  end

  describe "skipping invalid learned ids" do
    test "an active-skill id is silently skipped" do
      player = build_player(%{5 => 10}, :one_handed_sword)

      assert Passives.atk_bonus(player) == 0

      assert Passives.regen(player) ==
               %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: false}
    end

    test "an unknown id is silently skipped" do
      player = build_player(%{999_999 => 1}, :one_handed_sword)

      assert Passives.atk_bonus(player) == 0
    end
  end
end
