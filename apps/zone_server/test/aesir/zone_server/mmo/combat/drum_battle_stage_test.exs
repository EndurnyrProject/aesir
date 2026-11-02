defmodule Aesir.ZoneServer.Mmo.Combat.DrumBattleStageTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.TrapTestHelper
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @moduletag game_mode: :renewal

  setup :setup_ets_tables

  test "held Drum adds live damage to either hand without changing cached ATK or double counting on refold" do
    player =
      PlayerState.new(%Character{
        id: 8_140,
        account_id: 8_140,
        name: "Drum battle",
        class: 12,
        base_level: 50,
        job_level: 1,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 0,
        hp: 100,
        sp: 50,
        last_map: "prontera",
        last_x: 50,
        last_y: 50
      })

    :ok = UnitRegistry.register_player(player, self())

    worn = [
      %InventoryItem{id: 1, nameid: 1208, equip: EquipLocation.location_bit(:right_hand)},
      %InventoryItem{id: 2, nameid: 1208, equip: EquipLocation.location_bit(:left_hand)}
    ]

    stats = Calculator.calculate_stats(player.stats, player.character_id, worn)
    player = %{player | stats: stats}
    :ok = UnitRegistry.update_unit_state(:player, player.character_id, player)
    mob = TrapTestHelper.mob(8_141)
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    defender = MobState.to_combatant(mob)

    baseline =
      for path <- [:primary, :secondary], into: %{}, do: {path, damage(player, defender, path)}

    for {params, attack, defense} <- [
          {[val1: 5, duration: 180_000], 40, 75},
          {[val1: 1, val2: 27, val3: 42, loaded: true, duration: 12_000], 27, 42}
        ] do
      assert {:ok, [{:sc_drumbattle, :apply}]} =
               Interpreter.apply_status_with_events(
                 :player,
                 player.character_id,
                 :sc_drumbattle,
                 params
               )

      entry = StatusStorage.get_status(:player, player.character_id, :sc_drumbattle)
      assert {entry.val2, entry.val3} == {attack, defense}

      partial =
        Calculator.calculate_status_change(stats, player.character_id, :sc_drumbattle, :apply)

      assert partial.combat_stats.atk == stats.combat_stats.atk
      assert partial.combat_stats.physical_attack == stats.combat_stats.physical_attack
      assert partial.combat_stats.def == stats.combat_stats.def + defense
      boosted = %{player | stats: partial}

      for path <- [:primary, :secondary],
          do: assert(damage(boosted, defender, path) == baseline[path] + attack)

      full = %{player | stats: Calculator.calculate_stats(partial, player.character_id)}
      assert full.stats.combat_stats.atk == stats.combat_stats.atk

      for path <- [:primary, :secondary],
          do: assert(damage(full, defender, path) == baseline[path] + attack)

      assert :ok = Interpreter.remove_status(:player, player.character_id, :sc_drumbattle)

      for path <- [:primary, :secondary],
          do: assert(damage(boosted, defender, path) == baseline[path])
    end
  end

  defp damage(player, defender, path) do
    :rand.seed(:exsss, {101, 103, 107})

    assert {:ok, %{damage: damage}} =
             DamageCalculator.calculate_damage(PlayerState.to_combatant(player), defender,
               attack_path: path,
               skip_crit: true
             )

    damage
  end
end
