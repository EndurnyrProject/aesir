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

  In classic, the two shared refine programs run on private fixtures cloned from
  the available Jur and Guard; the newer corpus IDs are not added to shipped data.
  The trait glove's positive case is Renewal-only, paired with classic absence
  and inert trait-slot/AP checks.

  Unequip reverts by construction of the recompute model (stats are re-evaluated
  from the equipped set); each scenario asserts the equipped delta and that
  recomputing with no equipment returns to the bare baseline.
  """

  use Aesir.DataCase, async: true
  use Mimic

  @moduletag integration_re: true, integration_pre_re: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.ItemManagement
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

  setup do
    if GameMode.mode() == :pre_renewal do
      {:ok, katar} = ItemManagement.get_item_by_id(1250)
      {:ok, shield} = ItemManagement.get_item_by_id(2101)

      katar = %{katar | id: @katar_id, on_equip: [{:bonus, :critical, :refine}]}

      shield = %{
        shield
        | id: @shield_id,
          on_equip: [
            {:bonus, :mdef, 10},
            {:if, {:>, :refine, 7}, [{:bonus, :matk, 20}], []}
          ]
      }

      stub(ItemManagement, :get_item_by_id, fn
        @katar_id -> {:ok, katar}
        @shield_id -> {:ok, shield}
        id -> call_original(ItemManagement, :get_item_by_id, [id])
      end)
    end

    :ok
  end

  describe "flat trait bonuses (glove 490160)" do
    @describetag game_mode: :renewal, integration_pre_re: false
    test "equipping raises smatk by the flat bonus and spl-derived matk", %{account: account} do
      bare = account |> spawn_character("BareGlove", 0, 4252, 210) |> spawn_state()

      geared =
        account
        |> spawn_character("GearedGlove", 1, 4252, 210)
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

  @tag game_mode: :pre_renewal, integration_re: false
  test "classic excludes the trait glove and derives no trait combat slots", %{account: account} do
    assert {:error, _reason} = ItemManagement.get_item_by_id(@glove_id)
    character = spawn_character(account, "ClassicTraits", 0)
    state = spawn_state(%{character | pow: 10, spl: 10, con: 10, crt: 10, ap: 10})

    for field <- [:patk, :smatk, :res, :mres, :hplus, :crate] do
      assert Map.fetch!(combat(state), field) == 0
    end

    assert state.game_state.stats.derived_stats.max_ap == 0
    assert state.game_state.stats.current_state.ap == 0
  end

  describe "refine-scaled bonus (katar 1298)" do
    # Katar weapons double the effective critical rate (renewal), so the
    # refine-scaled `bonus bCritical,getrefine()` amount is applied first and the
    # whole crit is then doubled: bare has no katar (x1), the equipped set has (x2).
    test "critical scales with refine through the katar x2 doubling", %{account: account} do
      {class, level} = %{renewal: {4059, 105}, pre_renewal: {12, 50}}[GameMode.mode()]
      bare = account |> spawn_character("BareKatar", 2, class, level) |> spawn_state()

      unrefined =
        account
        |> spawn_character("KatarR0", 3, class, level)
        |> equip(@katar_id, @both_hand, 0)
        |> spawn_state()

      refined =
        account
        |> spawn_character("KatarR7", 4, class, level)
        |> equip(@katar_id, @both_hand, 7)
        |> spawn_state()

      assert combat(unrefined).critical_rate == combat(bare).critical_rate * 2
      assert combat(refined).critical_rate == (combat(bare).critical_rate + 70) * 2
      assert combat(unrefined).critical == div(combat(unrefined).critical_rate, 10)
      assert combat(refined).critical == div(combat(refined).critical_rate, 10)

      assert unequipped(refined).combat_stats.critical == combat(bare).critical
    end
  end

  describe "refine-gated conditional (shield 2198)" do
    test "mdef is unconditional and matk gates at refine 8", %{account: account} do
      {class, level} = %{renewal: {4252, 210}, pre_renewal: {1, 50}}[GameMode.mode()]
      bare = account |> spawn_character("BareShield", 5, class, level) |> spawn_state()

      below =
        account
        |> spawn_character("ShieldR7", 6, class, level)
        |> equip(@shield_id, @left_hand, 7)
        |> spawn_state()

      above =
        account
        |> spawn_character("ShieldR8", 7, class, level)
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

  defp spawn_character(account, name, char_num, class \\ 1, base_level \\ 50) do
    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: char_num,
        name: name,
        class: class,
        base_level: base_level,
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
