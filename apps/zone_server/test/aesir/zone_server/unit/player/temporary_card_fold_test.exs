defmodule Aesir.ZoneServer.Unit.Player.TemporaryCardFoldTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.NoEquip
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlWarp
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.TrapTestHelper
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    player =
      PlayerState.new(%Character{
        id: 7_711,
        account_id: 7_711,
        name: "Temporary card",
        class: 0,
        base_level: 1,
        job_level: 1,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 40,
        sp: 11,
        last_map: "prontera",
        last_x: 100,
        last_y: 100
      })

    :ok = UnitRegistry.register_player(player, self())
    %{player: player}
  end

  test "temporary card removal clears the empty-equipment fold and clamps without unequip effects",
       %{player: player} do
    card = %ItemDefinition{
      id: 999_991,
      aegis_name: "Temporary_Test",
      name: "Temporary test",
      type: :card,
      on_equip:
        EquipScript.parse!("bonus(ctx, :max_hp_rate, 100)\nbonus(ctx, :max_sp_rate, 100)"),
      on_unequip: EquipScript.parse!("status_end(ctx, :sc_blessing)")
    }

    stub(Items, :by_id, fn
      999_991 -> {:ok, card}
      id -> call_original(Items, :by_id, [id])
    end)

    :ok =
      StatusStorage.apply_status(:player, player.character_id, :sc_itemscript,
        val1: card.id,
        duration: 180_000
      )

    boosted = Calculator.calculate_stats(player.stats, player.character_id)
    assert boosted.derived_stats.max_hp == player.stats.derived_stats.max_hp * 2
    assert boosted.derived_stats.max_sp == player.stats.derived_stats.max_sp * 2
    assert boosted.current_state.hp == player.stats.current_state.hp
    assert boosted.current_state.sp == player.stats.current_state.sp
    assert boosted.worn_items == []
    assert boosted.card_unequip_effects == %{}

    full = %{
      boosted
      | current_state: %{
          boosted.current_state
          | hp: boosted.derived_stats.max_hp,
            sp: boosted.derived_stats.max_sp
        }
    }

    :ok = StatusStorage.remove_status(:player, player.character_id, :sc_itemscript)
    cleared = Calculator.calculate_stats(full, player.character_id)
    assert cleared.derived_stats.max_hp == player.stats.derived_stats.max_hp
    assert cleared.derived_stats.max_sp == player.stats.derived_stats.max_sp
    assert cleared.current_state.hp == cleared.derived_stats.max_hp
    assert cleared.current_state.sp == cleared.derived_stats.max_sp
    assert cleared.card_unequip_effects == %{}
    assert Map.get(cleared.modifiers.equipment, :max_hp_rate, 0) == 0
    assert Map.get(cleared.modifiers.equipment, :max_sp_rate, 0) == 0
  end

  test "mode-loaded temporary card programs reach real stat, combat and requirement consumers", %{
    player: player
  } do
    observer = self()
    {:ok, tao} = Items.by_id(4302)

    penalties =
      if GameMode.mode() == :renewal,
        do: "bonus bDefRate,-50; bonus bMdefRate,-50;",
        else: "bonus bDef,-50; bonus bMdef,-50;"

    assert {:ok, tao_program} = Transpiler.transpile_equip("bonus bMaxHPrate,100; " <> penalties)
    assert Map.get(EquipScript.eval(tao_program, %{lr_flag: :arrow}), :mdef_rate, 0) == 0

    armor = %ItemDefinition{
      id: 999_994,
      aegis_name: "Mdef_Test",
      name: "MDEF test",
      type: :armor,
      defense: 80,
      on_equip: EquipScript.parse!("bonus(ctx, :mdef, 80)")
    }

    stub(Items, :by_id, fn
      4302 -> {:ok, %{tao | on_equip: tao_program}}
      999_994 -> {:ok, armor}
      id -> call_original(Items, :by_id, [id])
    end)

    stub(CharacterPersistence, :update_stats, fn _id, _attrs, _opts -> :ok end)

    stub(PlayerSession, :apply_damage, fn _pid, damage, _source, metadata ->
      send(observer, {:damage, damage, metadata})
      :ok
    end)

    for id <- [4047, 4121, 4302, 4132, 4143, 4135] do
      :ok =
        StatusStorage.apply_status(:player, player.character_id, :sc_itemscript,
          val1: id,
          duration: 180_000
        )

      stats = Calculator.calculate_stats(player.stats, player.character_id)
      holder = %{player | stats: stats}
      :ok = UnitRegistry.update_unit_state(:player, player.character_id, holder)

      case id do
        4047 ->
          assert PlayerState.to_combatant(holder).element == {:ghost, 1}
          assert PlayerState.get_element(holder) == {:ghost, 1}
          frozen = put_in(holder.stats.modifiers.status_effects, %{element_override: {:water, 1}})
          assert PlayerState.to_combatant(frozen).element == {:water, 1}
          assert PlayerState.get_element(frozen) == {:water, 1}
          injured = put_in(holder.stats.current_state.hp, 1)

          assert {:noreply, recovered} =
                   NaturalHealHandler.handle_tick(
                     %SessionState{game_state: injured, connection_pid: self()},
                     500
                   )

          assert recovered.game_state.stats.current_state.hp == 1

        4121 ->
          assert stats.combat_stats.hit == player.stats.combat_stats.hit + 100

        4302 ->
          assert stats.derived_stats.max_hp == player.stats.derived_stats.max_hp * 2

          worn = [
            %InventoryItem{id: 1, nameid: armor.id, equip: EquipLocation.location_bit(:armor)}
          ]

          armored = Calculator.calculate_stats(player.stats, player.character_id, worn)
          expected = if GameMode.mode() == :renewal, do: 40, else: 30
          assert armored.combat_stats.def == expected
          assert armored.combat_stats.mdef == expected
          status_buffed = put_in(armored.modifiers.status_effects, %{mdef: 30})

          assert Calculator.calculate_combat_stats(status_buffed).combat_stats.mdef ==
                   expected + 30

          reduced = put_in(status_buffed.modifiers.equipment, %{mdef: 80, mdef_rate: -150})
          assert Calculator.calculate_combat_stats(reduced).combat_stats.mdef == 30

          if GameMode.mode() == :renewal do
            assert stats.modifiers.equipment.def_rate == -50
            assert stats.modifiers.equipment.mdef_rate == -50
          else
            assert stats.modifiers.equipment.def == -50
            assert stats.combat_stats.mdef == player.stats.combat_stats.mdef - 50
          end

        4132 ->
          assert PlayerCaster.effective_item_cost(holder, AlWarp.definition()) == []

          for name <- [:sa_abracadabra, :hw_ganbantein] do
            definition = %{name: name, item_cost: [%{id: 715, amount: 2}]}
            assert PlayerCaster.effective_item_cost(holder, definition) == [%{id: 715, amount: 1}]
          end

          assert Cost.resolve_sp(holder, AlWarp.definition(), 1, 100) == 125

        4143 ->
          assert Stats.get_effective_stat(stats, :vit) ==
                   Stats.get_effective_stat(player.stats, :vit) + 3

          assert {:error, :resisted} =
                   Interpreter.apply_status(:player, player.character_id, :sc_stun,
                     duration: 30_000,
                     caster_id: player.character_id
                   )

        4135 ->
          attacker = TrapTestHelper.mob(5_011)

          attacker = %{
            attacker
            | map_name: player.map_name,
              x: player.x + 1,
              y: player.y,
              calculated: %{attacker.calculated | batk: 100}
          }

          :ok = UnitRegistry.register_unit(:mob, attacker.instance_id, MobState, attacker, self())
          stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)

          stub(MobSession, :apply_damage, fn _pid, damage, _source, metadata ->
            send(observer, {:returned_damage, damage, metadata})
            :ok
          end)

          assert :ok = Combat.execute_mob_attack(attacker, player.character_id)
          assert_receive {:damage, taken, _metadata}
          assert_receive {:returned_damage, returned, %{reflected: true}}
          assert taken > 0
          assert returned > 0
          assert returned == div(taken * 30, 100)
      end
    end
  end

  test "a missing temporary item or program contributes no bonus", %{player: player} do
    empty = EquipmentFold.apply_equipment_modifiers(player.stats, nil, %{temporary_card_id: nil})

    for id <- [0, 999_999, 501] do
      folded =
        EquipmentFold.apply_equipment_modifiers(player.stats, nil, %{temporary_card_id: id})

      assert folded.modifiers.equipment == empty.modifiers.equipment
      assert folded.worn_items == []
    end
  end

  test "temporary card folds once after worn scripts without pretending to be equipped", %{
    player: player
  } do
    host = %ItemDefinition{
      id: 999_992,
      aegis_name: "Host_Test",
      name: "Host test",
      type: :weapon,
      weapon_level: 1,
      slots: 1,
      on_equip: EquipScript.parse!("grant_skill(ctx, 28, 3)")
    }

    card = %ItemDefinition{
      id: 999_993,
      aegis_name: "Neutral_Test",
      name: "Neutral test",
      type: :card,
      attack: 999,
      defense: 999,
      on_equip:
        EquipScript.parse!("""
        bonus(ctx, :hit, skill_lv(ctx, 28) + refine(ctx))
        bonus(ctx, {:addele, :fire}, 7)
        bonus(ctx, :dex, random_option(ctx, :value))
        if equipped(ctx, [999_993]) do
          bonus(ctx, :hit, 10_000)
        end
        """)
    }

    stub(Items, :by_id, fn
      999_992 -> {:ok, host}
      999_993 -> {:ok, card}
      id -> call_original(Items, :by_id, [id])
    end)

    Mimic.copy(NoEquip)
    stub(NoEquip, :restricted?, fn id, _map -> id == 999_993 end)

    worn = [
      %InventoryItem{
        id: 1,
        nameid: host.id,
        refine: 7,
        card0: 4121,
        equip: EquipLocation.location_bit(:left_hand)
      }
    ]

    inputs = %{
      temporary_card_id: card.id,
      map_name: "prontera",
      lr_flag: :arrow,
      random_option: %{id: 1, value: 1000, param: 0}
    }

    folded = EquipmentFold.apply_equipment_modifiers(player.stats, worn, inputs)
    assert folded.modifiers.equipment.hit == 103
    assert folded.modifiers.equipment[{:addele, :fire}] == 7
    assert Map.get(folded.modifiers.equipment, {:left_addele, :fire}, 0) == 0
    assert Map.get(folded.modifiers.equipment, :dex, 0) == 0
    assert folded.modifiers.equipment.def == 0
    assert length(folded.worn_items) == 1
    assert folded.card_unequip_effects == %{}
    repeated = EquipmentFold.apply_equipment_modifiers(folded, nil, inputs)
    assert repeated.modifiers.equipment == folded.modifiers.equipment
    assert repeated.worn_items == folded.worn_items
  end
end
