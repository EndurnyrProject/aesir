defmodule Aesir.ZoneServer.Mmo.Combat.TraitStatsIntegrationTest do
  @moduledoc """
  End-to-end coverage for script-driven equip bonuses feeding the renewal
  combat stats.

  Drives the real production path (no synthetic `CombatStats` construction):
  a clean-script item in `equip.yml` -> `ItemDefinition.on_equip` program ->
  `EquipScript.eval/2` against the item's refine -> `modifiers.equipment` ->
  `calculate_combat_stats/1` (via the real `PlayerSession.init/1` spawn path).

  Anchored on three real corpus items, each exercising a different slice of the
  engine:

    * `490160` Engraved Orlean's Glove (`bonus bSMatk,3; bonus bSpl,2; bonus
      bCrt,2;`) - a flat combat-trait key (`smatk`) and a base-trait key (`spl`,
      which feeds MATK) proving both trait families reach the derivation.
    * `1298` Shiver Katar (`bonus bCritical,getrefine();`) - refine-scaled amount
      plus the `:critical` equipment wiring.
    * `2198` Lapine Shield (`bonus bMdef,10; if (getrefine()>7) bonus bMatk,20;`)
      - an unconditional bonus plus a refine-gated conditional (boundary 7 vs 8).

  Unequip reverts by construction of the recompute model (stats are re-evaluated
  from the equipped set); each scenario asserts the equipped delta and that
  recomputing with no equipment returns to the bare baseline.
  """

  use Aesir.DataCase, async: true
  use Mimic

  @moduletag :integration

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.Stats

  # Engraved Orlean's Glove (accessory): bonus bSMatk,3; bonus bSpl,2; bonus bCrt,2
  @glove_id 490_160
  @accessory_slot 0x000008

  # Shiver Katar (two-handed weapon): bonus bCritical,getrefine()
  @katar_id 1298
  @both_hand 0x000022

  # Lapine Shield (left hand): bonus bMdef,10; if (getrefine()>7) bonus bMatk,20
  @shield_id 2198
  @left_hand 0x000020

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(ModifierCalculator)
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

  describe "flat trait bonuses (glove 490160)" do
    test "equipping raises smatk by the flat bonus and spl-derived matk", %{account: account} do
      bare = account |> spawn_character("BareGlove", 0) |> spawn_state()

      geared =
        account
        |> spawn_character("GearedGlove", 1)
        |> equip(@glove_id, @accessory_slot)
        |> spawn_state()

      equipment = geared.game_state.stats.modifiers.equipment
      assert equipment.smatk == 3
      assert equipment.spl == 2
      assert equipment.crt == 2

      # Combat-trait family: smatk +3 (base spl/con are 0, so the derivation term
      # is unchanged). Base-trait family: spl +2 feeds base MATK by 5*SPL = +10.
      assert combat(geared).smatk == combat(bare).smatk + 3
      assert combat(geared).matk_min == combat(bare).matk_min + 10

      reverted = unequipped(geared)
      assert reverted.combat_stats.smatk == combat(bare).smatk
      assert reverted.combat_stats.matk_min == combat(bare).matk_min
    end
  end

  describe "refine-scaled bonus (katar 1298)" do
    # Katar weapons double the effective critical rate (renewal), so the
    # refine-scaled `bonus bCritical,getrefine()` amount is applied first and the
    # whole crit is then doubled: bare has no katar (x1), the equipped set has (x2).
    test "critical scales with refine through the katar x2 doubling", %{account: account} do
      # Katar is an assassin (class 12) weapon; a swordman has no katar ASPD row.
      bare = account |> spawn_character("BareKatar", 2, 12) |> spawn_state()

      unrefined =
        account
        |> spawn_character("KatarR0", 3, 12)
        |> equip(@katar_id, @both_hand, 0)
        |> spawn_state()

      refined =
        account
        |> spawn_character("KatarR7", 4, 12)
        |> equip(@katar_id, @both_hand, 7)
        |> spawn_state()

      assert combat(unrefined).critical == combat(bare).critical * 2
      assert combat(refined).critical == (combat(bare).critical + 7) * 2

      assert unequipped(refined).combat_stats.critical == combat(bare).critical
    end
  end

  describe "refine-gated conditional (shield 2198)" do
    test "mdef is unconditional and matk gates at refine 8", %{account: account} do
      bare = account |> spawn_character("BareShield", 5) |> spawn_state()

      below =
        account
        |> spawn_character("ShieldR7", 6)
        |> equip(@shield_id, @left_hand, 7)
        |> spawn_state()

      above =
        account
        |> spawn_character("ShieldR8", 7)
        |> equip(@shield_id, @left_hand, 8)
        |> spawn_state()

      assert combat(below).mdef == combat(bare).mdef + 10
      assert combat(above).mdef == combat(bare).mdef + 10

      # The matk gate `getrefine() > 7` is closed at refine 7, open at refine 8.
      assert combat(below).matk == combat(bare).matk
      assert combat(above).matk == combat(bare).matk + 20

      reverted = unequipped(above)
      assert reverted.combat_stats.mdef == combat(bare).mdef
      assert reverted.combat_stats.matk == combat(bare).matk
    end
  end

  defp spawn_character(account, name, char_num, class \\ 1) do
    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: char_num,
        name: name,
        class: class,
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

  defp equip(character, nameid, equip_bitmask, refine \\ 0) do
    {:ok, _item} =
      Persistence.insert_item(character.id, %{
        nameid: nameid,
        amount: 1,
        equip: equip_bitmask,
        refine: refine
      })

    character
  end

  defp spawn_state(character) do
    {:ok, state} = PlayerSession.init(%{character: character, connection_pid: self()})
    state
  end

  defp combat(%{game_state: game_state}), do: game_state.stats.combat_stats

  # Simulates unequip via the recompute model: the same base stats recalculated
  # with no equipped items must return every combat stat to the bare baseline.
  defp unequipped(%{game_state: game_state}) do
    Stats.calculate_stats(game_state.stats, nil, [])
  end
end
