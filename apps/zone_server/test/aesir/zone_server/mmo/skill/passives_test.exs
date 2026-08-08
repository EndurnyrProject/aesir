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
  @weapon_ids %{
    one_handed_sword: 1101,
    mace: 1340,
    bow: 1701,
    knuckle: 1801,
    one_handed_axe: 1301,
    two_handed_axe: 1314,
    katar: 1250,
    dagger: 1201
  }
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

  defmodule ChanceMultiHitPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_005,
      name: :test_chance_multi_hit_passive,
      display_name: "Test Chance Multi Hit Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def attack_proc(_level, _ctx), do: %{multi_hit: 2, chance: 42}
  end

  defmodule MaxWeightPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_004,
      name: :test_max_weight_passive,
      display_name: "Test Max Weight Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def max_weight_bonus(level, _ctx), do: 2000 * level
  end

  defmodule StealProcPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_008,
      name: :test_steal_proc_passive,
      display_name: "Test Steal Proc Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def steal_proc(level, _ctx), do: %{chance_permille: 50 * level}
  end

  defmodule HigherStealProcPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_009,
      name: :test_higher_steal_proc_passive,
      display_name: "Test Higher Steal Proc Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def steal_proc(level, _ctx), do: %{chance_permille: 100 * level}
  end

  defmodule ShopDiscountPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_010,
      name: :test_shop_discount_passive,
      display_name: "Test Shop Discount Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def shop_discount_pct(level, _ctx), do: 4 * level
  end

  defmodule HigherShopDiscountPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_011,
      name: :test_higher_shop_discount_passive,
      display_name: "Test Higher Shop Discount Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def shop_discount_pct(level, _ctx), do: 5 * level
  end

  defmodule HiddenMoveSpeedPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_012,
      name: :test_hidden_move_speed_passive,
      display_name: "Test Hidden Move Speed Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def hidden_move_speed(level, _ctx), do: 100 * level
  end

  defmodule AfterNormalHitPassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_006,
      name: :test_after_normal_hit_passive,
      display_name: "Test After Normal Hit Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def after_normal_hit(player_state, hit) do
      send(Process.get(:after_normal_hit_probe), {:after_normal_hit, player_state, hit})
      :ok
    end
  end

  defmodule StatusAwarePassive do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.Skill,
      id: 9_900_007,
      name: :test_status_aware_passive,
      display_name: "Test Status Aware Passive",
      max_level: 10,
      target_type: :passive

    alias Aesir.ZoneServer.Mmo.Skill.Passive

    @behaviour Passive

    @impl Passive
    def max_sp_rate_bonus(level, _ctx), do: 2 * level

    @impl Passive
    def aspd_bonus(level, %{statuses_active?: true}), do: level
    def aspd_bonus(_level, _ctx), do: 0
  end

  defp build_player(learned_skills, weapon_atom) do
    inventory =
      if weapon_atom == :bare_hands do
        []
      else
        equip =
          if weapon_atom in [:bow, :two_handed_axe, :katar], do: @both_hand, else: @right_hand

        [
          %InventoryItem{
            nameid: Map.fetch!(@weapon_ids, weapon_atom),
            amount: 1,
            equip: equip,
            identify: 1
          }
        ]
      end

    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 10, int: 10, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 100},
      progression: %PlayerProgression{
        base_level: 50,
        job_level: 30,
        learned_skills: learned_skills
      },
      equipment: Stats.equipment_from_inventory(inventory)
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

    test "PR_MACEMASTERY level 5 with a mace grants 15 ATK" do
      player = build_player(%{65 => 5}, :mace)
      assert Passives.atk_bonus(player) == 15
    end

    test "MO_IRONHAND level 5 with a knuckle grants 15 ATK" do
      player = build_player(%{259 => 5}, :knuckle)
      assert Passives.atk_bonus(player) == 15
    end

    test "AM_AXEMASTERY level 10 with a one-handed axe grants 30 ATK" do
      player = build_player(%{226 => 10}, :one_handed_axe)

      assert Passives.atk_bonus(player) == 30
      assert Stats.calculate_combat_stats(player.stats).combat_stats.passive_atk == 30
    end

    test "AM_AXEMASTERY level 10 with a two-handed axe grants 30 ATK" do
      player = build_player(%{226 => 10}, :two_handed_axe)

      assert Passives.atk_bonus(player) == 30
      assert Stats.calculate_combat_stats(player.stats).combat_stats.passive_atk == 30
    end

    test "AM_AXEMASTERY level 10 with a one-handed sword grants 30 ATK" do
      player = build_player(%{226 => 10}, :one_handed_sword)

      assert Passives.atk_bonus(player) == 30
      assert Stats.calculate_combat_stats(player.stats).combat_stats.passive_atk == 30
    end

    test "AM_AXEMASTERY grants no ATK with another weapon or bare hands" do
      assert Passives.atk_bonus(build_player(%{226 => 10}, :mace)) == 0
      assert Passives.atk_bonus(build_player(%{226 => 10}, :bare_hands)) == 0
    end
  end

  describe "BS_WEAPONRESEARCH" do
    test "contributes mastery ATK and multiplicative hit rate" do
      player = build_player(%{107 => 5}, :one_handed_sword)
      calculated = Stats.calculate_combat_stats(player.stats)

      assert Passives.atk_bonus(player) == 10
      assert Passives.hit_rate_bonus_pct(player) == 10
      assert calculated.combat_stats.passive_atk == 10
      assert calculated.combat_stats.hit_rate_bonus_pct == 10
    end

    test "contributes no flat HIT, only the multiplicative hit rate" do
      # Renewal grants Weapon Research a hidden multiplicative bonus on the
      # already-clamped hit rate and NO flat HIT. Flat HIT is the pre-renewal
      # formula, so a non-zero `hit_bonus` here would silently ship pre-renewal
      # accuracy that still looks plausible in a stat window.
      #
      # This asserts the contribution, not whether the callback is exported:
      # every skill inherits a zero-returning default for all bonus channels,
      # so exporting it is meaningless — returning non-zero is the bug.
      player = build_player(%{107 => 10}, :one_handed_sword)

      assert Passives.hit_bonus(player) == 0
      assert Passives.hit_rate_bonus_pct(player) == 20
    end

    test "passives without a multiplicative hit-rate callback are unaffected" do
      player = build_player(%{2 => 5}, :one_handed_sword)

      assert Passives.hit_rate_bonus_pct(player) == 0
    end
  end

  describe "critical_bonus/1" do
    test "PR_MACEMASTERY level 5 with a mace grants 50 critical" do
      player = build_player(%{65 => 5}, :mace)
      assert Passives.critical_bonus(player) == 50
    end

    test "PR_MACEMASTERY grants no critical with another weapon" do
      player = build_player(%{65 => 5}, :bow)
      assert Passives.critical_bonus(player) == 0
    end

    test "existing passives contribute zero to the optional critical channel" do
      player = build_player(%{2 => 5}, :one_handed_sword)
      assert Passives.critical_bonus(player) == 0
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

    test "MO_DODGE level 3 grants 4 FLEE" do
      player = build_player(%{265 => 3}, :one_handed_sword)
      assert Passives.flee_bonus(player) == 4
    end
  end

  describe "dex_bonus/1, hit_bonus/1 and range_bonus/1" do
    test "all return 0 when no passive contributes the channel" do
      player = build_player(%{2 => 5}, :one_handed_sword)

      assert Passives.str_bonus(player) == 0
      assert Passives.str_bonus(player.stats) == 0
      assert Passives.dex_bonus(player) == 0
      assert Passives.hit_bonus(player) == 0
      assert Passives.range_bonus(player) == 0
      assert Passives.zeny_cost_reduction(player) == 0
      assert Passives.zeny_cost_reduction(player.stats) == 0
    end

    test "return 0 when no skills are learned" do
      player = build_player(%{}, :bow)

      assert Passives.str_bonus(player) == 0
      assert Passives.str_bonus(player.stats) == 0
      assert Passives.dex_bonus(player) == 0
      assert Passives.hit_bonus(player) == 0
      assert Passives.range_bonus(player) == 0
      assert Passives.zeny_cost_reduction(player) == 0
      assert Passives.zeny_cost_reduction(player.stats) == 0
    end
  end

  describe "max_weight_bonus/1" do
    test "returns 0 when no max-weight passive is learned" do
      player = build_player(%{2 => 5}, :one_handed_sword)
      assert Passives.max_weight_bonus(player) == 0
    end

    test "sums the max weight bonus contributed by a learned passive" do
      stub(Catalog, :by_id, fn 9_900_004 -> {:ok, MaxWeightPassive.definition()} end)

      stub(Catalog, :passive_module_for, fn :test_max_weight_passive ->
        {:ok, MaxWeightPassive}
      end)

      player = build_player(%{9_900_004 => 5}, :one_handed_sword)

      assert Passives.max_weight_bonus(player) == 10_000
    end
  end

  describe "max_sp_rate_bonus/1 and status context" do
    setup do
      stub(Catalog, :by_id, fn 9_900_007 -> {:ok, StatusAwarePassive.definition()} end)

      stub(Catalog, :passive_module_for, fn :test_status_aware_passive ->
        {:ok, StatusAwarePassive}
      end)

      :ok
    end

    test "aggregates the MaxSP rate channel" do
      player = build_player(%{9_900_007 => 5}, :one_handed_sword)

      assert Passives.max_sp_rate_bonus(player) == 10
    end

    test "passes explicit active-status presence to callbacks" do
      player = build_player(%{9_900_007 => 5}, :one_handed_sword)

      refute player.stats.modifiers.statuses_active?
      assert Passives.aspd_bonus(player) == 0

      active_stats = %{
        player.stats
        | modifiers: %{player.stats.modifiers | statuses_active?: true}
      }

      assert Passives.aspd_bonus(%{player | stats: active_stats}) == 5
    end
  end

  describe "weapon hand rates" do
    test "return the unmastered defaults despite unrelated passives" do
      player = build_player(%{2 => 5}, :one_handed_sword)

      assert Passives.right_hand_damage_rate(player) == 50
      assert Passives.left_hand_damage_rate(player) == 30
      assert Passives.katar_secondary_rate(player) == 1
      assert Passives.atk_bonus(player) == 20
    end

    test "learned masteries replace only their hand rates" do
      player = build_player(%{132 => 5, 133 => 5}, :one_handed_sword)

      assert Passives.right_hand_damage_rate(player) == 100
      assert Passives.left_hand_damage_rate(player) == 80
      assert Passives.katar_secondary_rate(player) == 1
      assert Passives.atk_bonus(player) == 0
    end

    test "Double Attack raises only the Katar secondary rate" do
      player = build_player(%{48 => 10}, :katar)

      assert Passives.katar_secondary_rate(player) == 21
      assert Passives.right_hand_damage_rate(player) == 50
      assert Passives.left_hand_damage_rate(player) == 30
      assert Passives.attack_procs(player) == %{}
    end

    test "preserves Double Attack HIT on its successful proc metadata" do
      player = build_player(%{48 => 7}, :dagger)

      assert Passives.attack_procs(player) == %{multi_hit: 2, chance: 49, hit_bonus: 7}
      assert Passives.hit_bonus(player) == 0
    end
  end

  describe "steal_proc/1" do
    test "keeps the highest chance from learned passive contributions" do
      stub(Catalog, :by_id, fn
        9_900_008 -> {:ok, StealProcPassive.definition()}
        9_900_009 -> {:ok, HigherStealProcPassive.definition()}
      end)

      stub(Catalog, :passive_module_for, fn
        :test_steal_proc_passive -> {:ok, StealProcPassive}
        :test_higher_steal_proc_passive -> {:ok, HigherStealProcPassive}
      end)

      player = build_player(%{9_900_008 => 5, 9_900_009 => 3}, :one_handed_sword)

      assert Passives.steal_proc(player) == 300
      assert Passives.steal_proc(player.stats) == 300
    end

    test "returns 0 when no passive contributes" do
      player = build_player(%{2 => 5}, :one_handed_sword)

      assert Passives.steal_proc(player) == 0
      assert Passives.steal_proc(player.stats) == 0
    end
  end

  describe "shop_discount_pct/1" do
    test "keeps the highest discount from learned passive contributions" do
      stub(Catalog, :by_id, fn
        9_900_010 -> {:ok, ShopDiscountPassive.definition()}
        9_900_011 -> {:ok, HigherShopDiscountPassive.definition()}
      end)

      stub(Catalog, :passive_module_for, fn
        :test_shop_discount_passive -> {:ok, ShopDiscountPassive}
        :test_higher_shop_discount_passive -> {:ok, HigherShopDiscountPassive}
      end)

      player = build_player(%{9_900_010 => 5, 9_900_011 => 3}, :one_handed_sword)

      assert Passives.shop_discount_pct(player) == 20
      assert Passives.shop_discount_pct(player.stats) == 20
    end

    test "returns 0 for players without discounts and non-player inputs" do
      player = build_player(%{2 => 5}, :one_handed_sword)

      assert Passives.shop_discount_pct(player) == 0
      assert Passives.shop_discount_pct(player.stats) == 0
      assert Passives.shop_discount_pct(:mob) == 0
    end
  end

  describe "hidden_move_speed/1" do
    test "keeps the highest speed penalty from learned passive contributions" do
      stub(Catalog, :by_id, fn
        9_900_012 -> {:ok, HiddenMoveSpeedPassive.definition()}
        213 -> {:ok, Aesir.ZoneServer.Mmo.Skills.Rogue.RgTunneldrive.definition()}
      end)

      stub(Catalog, :passive_module_for, fn
        :test_hidden_move_speed_passive -> {:ok, HiddenMoveSpeedPassive}
        :rg_tunneldrive -> {:ok, Aesir.ZoneServer.Mmo.Skills.Rogue.RgTunneldrive}
      end)

      player = build_player(%{9_900_012 => 1, 213 => 5}, :one_handed_sword)

      assert Passives.hidden_move_speed(player) == 100
      assert Passives.hidden_move_speed(player.stats) == 100
      assert Passives.hidden_move_speed(:mob) == 0
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

    test "carries the :chance of the winning multi_hit proc" do
      stub(Catalog, :by_id, fn 9_900_005 -> {:ok, ChanceMultiHitPassive.definition()} end)

      stub(Catalog, :passive_module_for, fn :test_chance_multi_hit_passive ->
        {:ok, ChanceMultiHitPassive}
      end)

      player = build_player(%{9_900_005 => 5}, :one_handed_sword)

      assert Passives.attack_procs(player) == %{multi_hit: 2, chance: 42}
    end

    test "a higher chanceless multi_hit proc wins over a lower proc with a chance" do
      stub(Catalog, :by_id, fn
        9_900_003 -> {:ok, HigherMultiHitPassive.definition()}
        9_900_005 -> {:ok, ChanceMultiHitPassive.definition()}
      end)

      stub(Catalog, :passive_module_for, fn
        :test_higher_multi_hit_passive -> {:ok, HigherMultiHitPassive}
        :test_chance_multi_hit_passive -> {:ok, ChanceMultiHitPassive}
      end)

      player = build_player(%{9_900_003 => 5, 9_900_005 => 5}, :one_handed_sword)

      assert Passives.attack_procs(player) == %{multi_hit: 3}
    end
  end

  describe "attack_replacement/1" do
    test "returns normal for a player without a replacement passive" do
      player = build_player(%{2 => 5}, :one_handed_sword)
      assert Passives.attack_replacement(player) == :normal
    end

    test "selects a learned Trifecta replacement" do
      :rand.seed(:exsss, {1, 2, 3})
      player = build_player(%{263 => 5}, :knuckle)

      assert {:skill_attack, opts, :quadruple} = Passives.attack_replacement(player)
      assert opts[:skill_id] == 263
      assert opts[:skill_level] == 5
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

  describe "sitting_regen/1" do
    test "collects Spiritual Cadence separately from ordinary passive regeneration" do
      player = build_player(%{260 => 5}, :one_handed_sword)

      assert Passives.sitting_regen(player) == %{sitting_hp_regen: 30, sitting_sp_regen: 11}

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

  describe "after_normal_hit/2" do
    @hit %{target_type: :mob, target_id: 2001, position: {150, 150}}

    test "invokes the callback of a learned passive with the player state and hit context" do
      Process.put(:after_normal_hit_probe, self())

      stub(Catalog, :by_id, fn 9_900_006 -> {:ok, AfterNormalHitPassive.definition()} end)

      stub(Catalog, :passive_module_for, fn :test_after_normal_hit_passive ->
        {:ok, AfterNormalHitPassive}
      end)

      player = build_player(%{9_900_006 => 5}, :one_handed_sword)

      assert :ok = Passives.after_normal_hit(player, @hit)
      assert_received {:after_normal_hit, ^player, @hit}
    end

    test "does not invoke the callback when the passive is not learned" do
      Process.put(:after_normal_hit_probe, self())

      player = build_player(%{2 => 5}, :one_handed_sword)

      assert :ok = Passives.after_normal_hit(player, @hit)
      refute_received {:after_normal_hit, _, _}
    end

    test "a learned passive without the callback implemented is a no-op" do
      player = build_player(%{2 => 5}, :one_handed_sword)

      assert :ok = Passives.after_normal_hit(player, @hit)
    end

    test "a player without computed stats is a no-op" do
      assert :ok = Passives.after_normal_hit(%PlayerState{}, @hit)
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
