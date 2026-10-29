defmodule Aesir.ZoneServer.Mmo.Combat.PotionRecoveryTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.PotionRecovery
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  @thrower_id 66_001
  @target_id 66_002
  @homunculus_gid 66_003

  setup :setup_ets_tables

  describe "thrower/1 and recipient/1" do
    test "read the learned levels, potion group rates, heal power and H.Plus of the thrower" do
      thrower =
        player(@thrower_id,
          learned: %{231 => 3, 227 => 2},
          hplus: 7,
          equipment: %{
            :heal_power => 4,
            {:skill_heal, 231} => 6,
            {:skill_heal, 28} => 50,
            {:add_item_group_heal, :potion} => 10,
            {:add_item_group_sp_heal, :potion} => 20,
            {:add_item_group_heal, :bluebox} => 99
          }
        )

      assert PotionRecovery.thrower(thrower) == %{
               pitcher: 3,
               learning_potion: 2,
               group_hp_rate: 10,
               group_sp_rate: 20,
               skill_heal: 10,
               hplus: 7
             }
    end

    test "a player recipient carries its effective VIT/INT, maxima, recovery skills and received heal power" do
      target =
        player(@target_id,
          vit: 12,
          int: 8,
          learned: %{4 => 5, 9 => 3},
          equipment: %{:heal_power2 => 5, {:skill_heal2, 231} => 3, {:skill_heal2, 28} => 40}
        )

      assert PotionRecovery.recipient(target) == %{
               ref: {:player, @target_id},
               player?: true,
               vit: 12,
               int: 8,
               max_hp: 1_000,
               max_sp: 500,
               hp_recovery: 5,
               sp_recovery: 3,
               received_heal: 8
             }
    end

    test "a Homunculus recipient has no recovery skills or received heal power" do
      assert %{
               ref: {:homunculus, @homunculus_gid},
               player?: false,
               vit: 30,
               int: 20,
               max_hp: 900,
               max_sp: 300,
               hp_recovery: 0,
               sp_recovery: 0,
               received_heal: 0
             } = PotionRecovery.recipient(homunculus())
    end
  end

  describe "player_throw/3" do
    test "flat HP: Pitcher and Learning Potion, then VIT, then Increase HP Recovery, each truncating" do
      thrower = thrower(pitcher: 5, learning_potion: 2)
      recipient = recipient(vit: 15, hp_recovery: 3)

      # 57 * 160 * 100 / 10000 = 91; * 130 / 100 = 118; * 130 / 100 = 153
      assert PotionRecovery.player_throw(thrower, recipient, potion(hp: 57)) == {153, 0}
    end

    test "flat SP uses INT and Increase SP Recovery" do
      thrower = thrower(pitcher: 5, learning_potion: 10)
      recipient = recipient(int: 11, sp_recovery: 2)

      # 47 * 200 / 100 = 94; * 122 / 100 = 114; * 120 / 100 = 136
      assert PotionRecovery.player_throw(thrower, recipient, potion(sp: 47)) == {0, 136}
    end

    test "a non-player recipient skips the recovery skills" do
      recipient = %{recipient(vit: 15, hp_recovery: 3) | player?: false, ref: {:mob, 1}}

      assert PotionRecovery.player_throw(thrower(pitcher: 5), recipient, potion(hp: 57)) ==
               {110, 0}
    end

    test "percent potions scale the recipient's maxima by the thrower only" do
      thrower = thrower(pitcher: 2, learning_potion: 1)
      recipient = recipient(vit: 99, hp_recovery: 10)

      # 1000 * 7 / 100 = 70; * 125 / 100 = 87 ; 500 * 3 / 100 = 15; * 125 / 100 = 18
      assert PotionRecovery.player_throw(thrower, recipient, potion(per_hp: 7, per_sp: 3)) ==
               {87, 18}
    end

    test "a percent potion wins over a flat one in the same script" do
      assert PotionRecovery.player_throw(thrower(), recipient(), potion(hp: 500, per_hp: 1)) ==
               {10, 0}
    end

    test "a non-player recipient of a percent potion takes no SP" do
      recipient = %{recipient() | player?: false, ref: {:mob, 1}}

      assert PotionRecovery.player_throw(thrower(), recipient, potion(per_hp: 10, per_sp: 10)) ==
               {100, 0}
    end

    test "then the potion group rates, heal power, received heal power and H.Plus compound in order" do
      thrower =
        thrower(group_hp_rate: 10, group_sp_rate: 20, skill_heal: 15, hplus: 9)

      recipient = recipient(received_heal: 13)

      # HP 100 -> 110 -> 126 -> 142 -> 154 ; SP 100 -> 120 -> 138 -> 155 -> 168
      assert PotionRecovery.player_throw(thrower, recipient, potion(hp: 100, sp: 100)) ==
               {154, 168}
    end

    test "received heal power reaches only a player recipient" do
      recipient = %{recipient(received_heal: 50) | player?: false, ref: {:mob, 1}}

      assert PotionRecovery.player_throw(thrower(), recipient, potion(hp: 100)) == {100, 0}
    end

    test "Increase Heal Rate on the recipient does not touch a thrown potion" do
      :ok = StatusStorage.apply_status(:player, @target_id, :sc_inchealrate, val1: 50)

      assert PotionRecovery.player_throw(thrower(), recipient(), potion(hp: 100)) == {100, 0}
    end

    test "No Recovery on the recipient cancels both" do
      :ok = StatusStorage.apply_status(:player, @target_id, :sc_norecover_state)

      assert PotionRecovery.player_throw(thrower(), recipient(), potion(hp: 100, sp: 100)) ==
               {0, 0}
    end

    @tag game_mode: :renewal
    test "renewal: Asura recovery on the recipient cancels the SP" do
      :ok = StatusStorage.apply_status(:player, @target_id, :sc_extremityfist)

      assert PotionRecovery.player_throw(thrower(), recipient(), potion(hp: 100, sp: 100)) ==
               {100, 0}
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal: Asura recovery does not touch the SP" do
      :ok = StatusStorage.apply_status(:player, @target_id, :sc_extremityfist)

      assert PotionRecovery.player_throw(thrower(), recipient(), potion(hp: 100, sp: 100)) ==
               {100, 100}
    end

    @tag game_mode: :renewal
    test "renewal: a Homunculus takes three times the final HP, not the SP" do
      recipient = PotionRecovery.recipient(homunculus())

      # 101 * 160 / 100 = 161; H.Plus -> 177; x3
      assert PotionRecovery.player_throw(thrower(hplus: 10), recipient, potion(hp: 101, sp: 10)) ==
               {531, 15}
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal: a Homunculus takes the HP once" do
      recipient = PotionRecovery.recipient(homunculus())

      assert PotionRecovery.player_throw(thrower(hplus: 10), recipient, potion(hp: 101, sp: 10)) ==
               {177, 15}
    end
  end

  describe "monster_throw/2" do
    test "each level's base plus a roll, the level rate, VIT and a player's Increase HP Recovery" do
      :rand.seed(:exsss, {1, 2, 3})
      roll = :rand.uniform(41) - 1
      :rand.seed(:exsss, {1, 2, 3})

      recipient = recipient(vit: 10, hp_recovery: 2, received_heal: 10)
      hp = div(div(div((105 + roll) * 170, 100) * 120, 100) * 120, 100)

      assert PotionRecovery.monster_throw(2, recipient) == {hp + div(hp * 10, 100), 0}
    end

    test "levels 4 and above use the White Potion base" do
      for level <- [4, 5] do
        :rand.seed(:exsss, {4, 5, 6})
        roll = :rand.uniform(level * 20 + 1) - 1
        :rand.seed(:exsss, {4, 5, 6})
        recipient = %{recipient() | player?: false, ref: {:mob, 1}}

        assert PotionRecovery.monster_throw(level, recipient) ==
                 {div((325 + roll) * (150 + level * 10), 100), 0}
      end
    end
  end

  defp thrower(opts \\ []) do
    Map.merge(
      %{
        pitcher: 0,
        learning_potion: 0,
        group_hp_rate: 0,
        group_sp_rate: 0,
        skill_heal: 0,
        hplus: 0
      },
      Map.new(opts)
    )
  end

  defp recipient(opts \\ []) do
    Map.merge(
      %{
        ref: {:player, @target_id},
        player?: true,
        vit: 0,
        int: 0,
        max_hp: 1_000,
        max_sp: 500,
        hp_recovery: 0,
        sp_recovery: 0,
        received_heal: 0
      },
      Map.new(opts)
    )
  end

  defp potion(opts), do: Map.merge(%{hp: 0, sp: 0, per_hp: 0, per_sp: 0}, Map.new(opts))

  describe "Slim Pitcher" do
    test "the caster's rate sums the three skills and its own heal bonus, then H.Plus adds" do
      thrower =
        player(@thrower_id,
          learned: %{478 => 10, 231 => 5, 227 => 10},
          hplus: 5,
          equipment: %{
            :heal_power => 50,
            {:skill_heal, 478} => 10,
            {:skill_heal, 231} => 30
          }
        )

      # 100 + 10*10 + 10*5 + 5*10 + 10 = 310 percent, heal power ignored: 100 -> 310, 40 -> 124;
      # H.Plus 5 then adds 15 and 6.
      assert PotionRecovery.slim_throw(
               %{hp: 100, sp: 40, per_hp: 0, per_sp: 0},
               PotionRecovery.slim_thrower(thrower)
             ) == {325, 130}
    end

    test "a player recipient scales by VIT/INT, then its recovery skills and Slim Pitcher heal bonus" do
      target =
        player(@target_id,
          vit: 12,
          int: 8,
          learned: %{4 => 5, 9 => 3},
          equipment: %{:heal_power2 => 5, {:skill_heal2, 478} => 3, {:skill_heal2, 231} => 40}
        )

      # HP 100 * 124% = 124, then * (100 + 50 + 8)% = 195; SP 50 * 116% = 58, then * 138% = 80.
      assert PotionRecovery.slim_receive({100, 50}, PotionRecovery.recipient(target, 478)) ==
               {195, 80}
    end

    test "a Homunculus recipient scales by VIT/INT only, with no multiplier" do
      assert PotionRecovery.slim_receive({100, 50}, PotionRecovery.recipient(homunculus(), 478)) ==
               {160, 70}
    end

    test "a monster recipient scales by its VIT and INT only" do
      spawn = %MobSpawn{
        mob: 1002,
        amount: 1,
        respawn_time: 0,
        spawn_area: %MobSpawn.SpawnArea{x: 0, y: 0}
      }

      mob = MobState.new(66_004, Aesir.TestMob.definition(), spawn, "test", 0, 0)

      # VIT 10: 100 * 120% = 120; INT 5: 50 * 110% = 55.
      assert PotionRecovery.slim_receive({100, 50}, PotionRecovery.recipient(mob, 478)) ==
               {120, 55}
    end

    test "No Recover cancels the heal" do
      target = player(@target_id, vit: 12)
      :ok = StatusStorage.apply_status(:player, @target_id, :sc_norecover_state)

      assert PotionRecovery.slim_receive({100, 50}, PotionRecovery.recipient(target, 478)) ==
               {0, 0}
    end
  end

  defp player(id, opts) do
    %PlayerState{
      character_id: id,
      account_id: 1,
      stats: %Stats{
        base_stats: %{vit: Keyword.get(opts, :vit, 0), int: Keyword.get(opts, :int, 0)},
        current_state: %CurrentState{hp: 10, sp: 10},
        derived_stats: %DerivedStats{max_hp: 1_000, max_sp: 500, aspd: 150},
        combat_stats: %{hplus: Keyword.get(opts, :hplus, 0)},
        modifiers: %{
          equipment: Keyword.get(opts, :equipment, %{}),
          status_effects: %{},
          job_bonuses: %{},
          passive: %{}
        },
        progression: %PlayerProgression{
          base_level: 1,
          job_level: 1,
          job_id: 0,
          learned_skills: Keyword.get(opts, :learned, %{})
        }
      }
    }
  end

  defp homunculus do
    %HomunculusState{
      id: 1,
      owner_character_id: @thrower_id,
      class_id: 6_001,
      name: "Hildr",
      lifecycle: :active,
      hp: 100,
      max_hp: 900,
      sp: 10,
      max_sp: 300,
      vit: 30,
      int: 20,
      world_gid: @homunculus_gid,
      map_name: "test",
      x: 10,
      y: 10
    }
  end
end
