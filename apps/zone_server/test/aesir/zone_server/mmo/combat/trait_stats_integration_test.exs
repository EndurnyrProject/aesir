defmodule Aesir.ZoneServer.Mmo.Combat.TraitStatsIntegrationTest do
  @moduledoc """
  End-to-end coverage for the renewal P.Atk/Res combat stats.

  Drives the real production path (no synthetic `CombatStats`/`Combatant`
  construction for the player side): sample gear in `equip.yml` ->
  `ItemDefinition` -> `accumulate_item_bonus/2` -> `calculate_combat_stats/1`
  (via the real `PlayerSession.init/1` spawn path) -> `PlayerState.to_combatant/1`
  -> `DamageCalculator.calculate_damage/3`.
  """

  use Aesir.DataCase, async: true
  use Mimic

  @moduletag :integration

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # Destruction Axe (equip.yml, weapon_level 5): carries `patk: 20`.
  @weapon_id 1341
  @weapon_patk 20
  @right_hand 0x000002

  # Rabbit Pattern Shirt (equip.yml, armor_level 2): carries `res: 15`.
  @armor_id 15_282
  @armor_res 15
  @armor_slot 0x000010

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(RaceModifiers)
    Mimic.copy(CriticalHits)
    Mimic.copy(ModifierCalculator)

    stub(ElementModifiers, :get_modifier, fn _, _, _ -> 1.0 end)
    stub(SizeModifiers, :get_modifier, fn _, _ -> 1.0 end)
    stub(SizeModifiers, :player_size, fn -> :medium end)
    stub(RaceModifiers, :player_race, fn -> :human end)

    stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
      %{damage: damage, is_critical: false}
    end)

    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)

    :ok
  end

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "trait_stats_user",
        userid: "trait_stats_user",
        user_pass: "password",
        email: "trait_stats@test.com"
      })
      |> Repo.insert()

    %{account: account}
  end

  test "the sample gear carries the new fields and loads into ItemDefinition" do
    assert {:ok, %{patk: @weapon_patk}} = ItemManagement.get_item_by_id(@weapon_id)
    assert {:ok, %{res: @armor_res}} = ItemManagement.get_item_by_id(@armor_id)
  end

  describe "equip -> CombatStats" do
    test "equipping the patk weapon raises combat_stats.patk by the item's value", %{
      account: account
    } do
      bare = account |> spawn_character("BareAtk", 0) |> spawn_state()

      geared =
        account
        |> spawn_character("GearedAtk", 1)
        |> equip(@weapon_id, @right_hand)
        |> spawn_state()

      assert geared.game_state.stats.combat_stats.patk ==
               bare.game_state.stats.combat_stats.patk + @weapon_patk
    end

    test "equipping the res armor raises combat_stats.res by the item's value", %{
      account: account
    } do
      bare = account |> spawn_character("BareDef", 2) |> spawn_state()

      geared =
        account
        |> spawn_character("GearedDef", 3)
        |> equip(@armor_id, @armor_slot)
        |> spawn_state()

      assert geared.game_state.stats.combat_stats.res ==
               bare.game_state.stats.combat_stats.res + @armor_res
    end
  end

  describe "CombatStats -> DamageCalculator" do
    test "equipping the patk weapon increases melee damage against the same defender", %{
      account: account
    } do
      defender = CombatTestHelper.create_mob_combatant()

      bare_attacker =
        account |> spawn_character("BareAttacker", 4) |> spawn_state() |> to_combatant()

      geared_attacker =
        account
        |> spawn_character("GearedAttacker", 5)
        |> equip(@weapon_id, @right_hand)
        |> spawn_state()
        |> to_combatant()

      assert geared_attacker.combat_stats.patk == bare_attacker.combat_stats.patk + @weapon_patk

      # Seed identically before each call so the weapon-ATK variance band (renewal 80-120%)
      # is the same for both, isolating the P.Atk difference under test.
      :rand.seed(:exsss, {1, 2, 3})

      {:ok, bare_result} =
        DamageCalculator.calculate_damage(bare_attacker, defender, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, geared_result} =
        DamageCalculator.calculate_damage(geared_attacker, defender, skip_crit: true)

      assert geared_result.damage > bare_result.damage
    end

    test "equipping the res armor reduces incoming melee damage from the same attacker", %{
      account: account
    } do
      attacker = CombatTestHelper.create_player_combatant(str: 60, base_level: 90)

      bare_defender =
        account |> spawn_character("BareDefender", 6) |> spawn_state() |> to_combatant()

      geared_defender =
        account
        |> spawn_character("GearedDefender", 7)
        |> equip(@armor_id, @armor_slot)
        |> spawn_state()
        |> to_combatant()

      assert geared_defender.combat_stats.res == bare_defender.combat_stats.res + @armor_res

      # Seed identically before each call so the attacker's weapon-ATK variance is the same
      # for both, isolating the defender Res reduction under test.
      :rand.seed(:exsss, {1, 2, 3})

      {:ok, bare_result} =
        DamageCalculator.calculate_damage(attacker, bare_defender, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, geared_result} =
        DamageCalculator.calculate_damage(attacker, geared_defender, skip_crit: true)

      assert geared_result.damage < bare_result.damage
    end
  end

  defp spawn_character(account, name, char_num) do
    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: char_num,
        name: name,
        class: 1,
        base_level: 50,
        last_map: "prontera",
        last_x: 50,
        last_y: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    character
  end

  defp equip(character, nameid, equip_bitmask) do
    {:ok, _item} =
      Persistence.insert_item(character.id, %{nameid: nameid, amount: 1, equip: equip_bitmask})

    character
  end

  defp spawn_state(character) do
    {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})
    state
  end

  defp to_combatant(%{game_state: game_state}), do: PlayerState.to_combatant(game_state)
end
