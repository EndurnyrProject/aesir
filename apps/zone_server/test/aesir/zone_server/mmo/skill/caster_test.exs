defmodule Aesir.ZoneServer.Mmo.Skill.CasterTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegen
  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.Renewal
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Requirement
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Transpiler.Parser
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  setup :setup_ets_tables

  test "resolves each caster state to its adapter" do
    assert Caster.for(player()) == Caster.Player
    assert Caster.for(homunculus()) == Caster.Homunculus
    assert Caster.for(mob()) == Caster.Mob
  end

  test "rejects unknown caster structs clearly" do
    assert_raise ArgumentError, ~r/unsupported skill caster.*URI/, fn ->
      Caster.for(%URI{})
    end
  end

  test "player adapter exposes identity, geometry, range, and facilities" do
    state = player()

    assert Caster.Player.kind() == :player
    assert Caster.Player.provides() == Requirement.all()
    assert Enum.all?(Caster.Player.provides(), &Requirement.valid?/1)
    assert Caster.Player.id(state) == 101
    assert Caster.Player.unit_type(state) == :player
    assert Caster.Player.position(state) == {"prontera", 10, 20}
    assert Caster.Player.attack_range(state) == 1
    assert Caster.Player.broadcast_source(state) == 101
  end

  test "homunculus adapter exposes identity, geometry, range, and facilities" do
    state = homunculus()

    assert Caster.Homunculus.kind() == :homunculus
    assert Caster.Homunculus.provides() == [:homunculus_state]
    assert Enum.all?(Caster.Homunculus.provides(), &Requirement.valid?/1)
    assert Caster.Homunculus.id(state) == 301
    assert Caster.Homunculus.unit_type(state) == :homunculus
    assert Caster.Homunculus.position(state) == {"prontera", 11, 21}
    assert Caster.Homunculus.attack_range(state) == 3
    assert Caster.Homunculus.broadcast_source(state) == {:homunculus, 301}
  end

  test "mob adapter exposes identity, geometry, range, and facilities" do
    state = mob()

    assert Caster.Mob.kind() == :mob
    assert Caster.Mob.provides() == []
    assert Enum.all?(Caster.Mob.provides(), &Requirement.valid?/1)
    assert Caster.Mob.id(state) == 401
    assert Caster.Mob.unit_type(state) == :mob
    assert Caster.Mob.position(state) == {"prontera", 12, 22}
    assert Caster.Mob.attack_range(state) == 7
    assert Caster.Mob.broadcast_source(state) == {:mob, 401}
  end

  test "monster timing inputs use effective battle stats without item channels" do
    inputs = Caster.Mob.cast_stats(mob(), 83)
    assert %{caster_kind: :mob, effective_skill?: true, statuses: %{}} = inputs
    assert inputs.dex == mob().mob_data.stats.dex
  end

  test "emitted bCastRate modifiers affect renewal and pre-renewal casts" do
    definition = %Definition{
      id: 83,
      name: :test_skill,
      display_name: "Test Skill",
      max_level: 1,
      cast_time: [1_000],
      fixed_cast_time: [200]
    }

    baseline_stats = Caster.Player.cast_stats(cast_player(%{}), definition.id)
    baseline_renewal = Renewal.compute(definition, 1, baseline_stats)
    baseline_pre_renewal = PreRenewal.compute(definition, 1, baseline_stats)

    results =
      Map.new([-25, 25], fn rate ->
        modifiers = emitted_cast_modifiers(rate)
        assert modifiers == %{varcast_rate: rate}

        stats = Caster.Player.cast_stats(cast_player(modifiers), definition.id)
        assert stats.item_global_rate == -rate
        assert stats.item_skill_rate == 0

        {rate,
         %{
           renewal: Renewal.compute(definition, 1, stats),
           pre_renewal: PreRenewal.compute(definition, 1, stats)
         }}
      end)

    assert results[-25].renewal.total < baseline_renewal.total
    assert results[25].renewal.total > baseline_renewal.total
    assert results[-25].pre_renewal.total < baseline_pre_renewal.total
    assert results[25].pre_renewal.total > baseline_pre_renewal.total
  end

  test "IgnoreItemBonus skills skip equipment cast rates and IgnoreStatus skills skip status reductions" do
    caster = cast_player(%{varcast_rate: -25, fixcast_rate: -50, fixed_cast: -100})
    Mimic.stub(ModifierCalculator, :get_all_modifiers, fn :player, 101 -> %{} end)

    :ok =
      StatusStorage.apply_status(:player, 101, :sc_suffragium, state: %{cast_time_reduction: 30})

    amp = Caster.Player.cast_stats(caster, 366)

    assert %{
             item_global_rate: 25,
             item_global_fixed_rate: 50,
             item_global_fixed_flat: -100,
             statuses: %{suffragium: 30}
           } = amp

    foresight = Caster.Player.cast_stats(caster, 403)
    assert foresight.statuses == %{suffragium: 30}

    {:ok, amp_definition} = Catalog.by_id(366)
    {:ok, foresight_definition} = Catalog.by_id(403)
    mode = if GameMode.mode() == :renewal, do: Renewal, else: PreRenewal

    without_items =
      %{amp | item_global_rate: 0, item_global_fixed_rate: 0, item_global_fixed_flat: 0}

    assert mode.compute(amp_definition, 1, amp) == mode.compute(amp_definition, 1, without_items)

    without_statuses = %{foresight | statuses: %{}}

    assert mode.compute(foresight_definition, 1, foresight) ==
             mode.compute(foresight_definition, 1, without_statuses)
  end

  test "Into the Abyss waives gemstones except for Ganbantein, which still needs one of each" do
    caster = cast_player(%{})
    :ok = StatusStorage.apply_status(:player, 101, :sc_intoabyss)
    {:ok, ganbantein} = Catalog.by_name(:hw_ganbantein)
    {:ok, gravitation} = Catalog.by_id(484)

    assert Caster.Player.effective_item_cost(caster, ganbantein) == ganbantein.item_cost

    assert Caster.Player.effective_item_cost(caster, %{
             gravitation
             | item_cost: [%{id: 717, amount: 1}]
           }) == []
  end

  describe "the cast-end ammunition requirement" do
    test "accepts an arrow of the required type and consumes the level's amount" do
      caster = ammo_caster(1_750, 3)
      definition = ammo_definition([])

      assert {:ok, prepared} =
               Caster.Player.castend_cost(caster, __MODULE__, {:unit, 9_999}, definition, 1)

      assert prepared.ammo_qty == 1

      paid = Caster.Player.commit(caster, prepared)
      assert paid.inventory[1].amount == 2
      assert [{_old, new_inventory, {:reduced, 1, 2}}] = paid.pending_inventory_persist
      assert new_inventory == paid.inventory
    end

    test "refuses ammunition of a subtype the skill does not allow" do
      caster = ammo_caster(1_750, 3)
      definition = ammo_definition(require_ammo: [:dagger])

      assert {:error, :no_ammo} =
               Caster.Player.castend_cost(caster, __MODULE__, {:unit, 9_999}, definition, 1)
    end

    test "refuses a stack shorter than the level's amount" do
      caster = ammo_caster(1_750, 4)
      definition = ammo_definition(ammo_qty: List.duplicate(5, 10))

      assert {:error, :no_ammo} =
               Caster.Player.castend_cost(caster, __MODULE__, {:unit, 9_999}, definition, 1)
    end

    test "refuses an empty ammo slot" do
      caster =
        PlayerStateFixture.build(%{
          character_id: 101,
          stats: %PlayerStats{},
          inventory: %{}
        })

      assert {:error, :no_ammo} =
               Caster.Player.castend_cost(
                 caster,
                 __MODULE__,
                 {:unit, 9_999},
                 ammo_definition([]),
                 1
               )
    end

    @tag game_mode: :renewal
    test "renewal checks one extra arrow for Severe Rainstorm and consumes its own amount" do
      definition =
        ammo_definition(
          id: 2_418,
          name: :wm_severe_rainstorm,
          ammo_qty: List.duplicate(10, 10)
        )

      assert {:error, :no_ammo} =
               Caster.Player.castend_cost(
                 ammo_caster(1_750, 10),
                 __MODULE__,
                 {:unit, 9_999},
                 definition,
                 1
               )

      caster = ammo_caster(1_750, 11)

      assert {:ok, prepared} =
               Caster.Player.castend_cost(caster, __MODULE__, {:unit, 9_999}, definition, 1)

      assert prepared.ammo_qty == 10
      assert Caster.Player.commit(caster, prepared).inventory[1].amount == 1
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal checks no extra arrow for Severe Rainstorm" do
      definition =
        ammo_definition(
          id: 2_418,
          name: :wm_severe_rainstorm,
          ammo_qty: List.duplicate(10, 10)
        )

      caster = ammo_caster(1_750, 10)

      assert {:ok, prepared} =
               Caster.Player.castend_cost(caster, __MODULE__, {:unit, 9_999}, definition, 1)

      refute Map.has_key?(Caster.Player.commit(caster, prepared).inventory, 1)
    end
  end

  describe "the 90 percent weight refusal" do
    test "refuses at exactly the threshold at cast begin and cast end, and allows one potion less" do
      definition = weight_definition()

      at_limit = potion_caster(261)
      at_limit_cost = Cost.from_definition(at_limit, definition, 1, sp: 0)

      assert {:error, :overweight} =
               Caster.Player.prepare_begin_cost(
                 at_limit,
                 __MODULE__,
                 definition,
                 at_limit_cost,
                 0,
                 1
               )

      assert {:error, :overweight} =
               Caster.Player.prepare_castend_cost(
                 at_limit,
                 __MODULE__,
                 {:unit, 9_999},
                 1,
                 definition,
                 at_limit_cost,
                 0
               )

      under_limit = potion_caster(260)
      under_limit_cost = Cost.from_definition(under_limit, definition, 1, sp: 0)

      assert {:ok, _prepared} =
               Caster.Player.prepare_begin_cost(
                 under_limit,
                 __MODULE__,
                 definition,
                 under_limit_cost,
                 0,
                 1
               )

      assert {:ok, _prepared} =
               Caster.Player.prepare_castend_cost(
                 under_limit,
                 __MODULE__,
                 {:unit, 9_999},
                 1,
                 definition,
                 under_limit_cost,
                 0
               )
    end
  end

  # A novice's 20_000 carry weight plus the fixture's 1 STR (300) is 20_300, so
  # 90 percent is 18_270: 261 Red Potions (70 each) sit exactly on the limit.
  defp potion_caster(potions) do
    PlayerStateFixture.build(%{
      character_id: 101,
      stats: %PlayerStats{},
      inventory: %{1 => %InventoryItem{nameid: 501, amount: potions}}
    })
  end

  defp weight_definition do
    %Definition{
      id: 46,
      name: :ac_double,
      display_name: "Double Strafe",
      max_level: 10,
      target_type: :target_enemy,
      damage_type: :damage,
      sp_cost: [0]
    }
  end

  defp ammo_caster(nameid, amount) do
    PlayerStateFixture.build(%{
      character_id: 101,
      stats: %PlayerStats{},
      inventory: %{1 => %InventoryItem{nameid: nameid, amount: amount, equip: 0x008000}}
    })
  end

  defp ammo_definition(attrs) do
    struct!(
      %Definition{
        id: 46,
        name: :ac_double,
        display_name: "Double Strafe",
        max_level: 10,
        target_type: :target_enemy,
        damage_type: :damage,
        sp_cost: List.duplicate(12, 10),
        require_ammo: [:arrow],
        ammo_qty: List.duplicate(1, 10)
      },
      attrs
    )
  end

  defp emitted_cast_modifiers(rate) do
    {:ok, statements} = Parser.parse_body("bonus bCastRate,#{rate};")
    {:ok, program} = EquipCodegen.generate(statements)

    EquipScript.eval(program, %{refine: 0, base_level: 1, job_level: 1})
  end

  defp cast_player(equipment_modifiers) do
    state = player()

    stats = %{
      state.stats
      | base_stats: %BaseStats{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        modifiers: %{state.stats.modifiers | equipment: equipment_modifiers}
    }

    %{state | stats: stats}
  end

  defp player do
    %PlayerState{
      character_id: 101,
      map_name: "prontera",
      x: 10,
      y: 20,
      stats: %PlayerStats{equipment: %Equipment{}}
    }
  end

  defp homunculus do
    %HomunculusState{
      id: 201,
      owner_character_id: 101,
      class_id: 6_001,
      name: "Lif",
      world_gid: 301,
      map_name: "prontera",
      x: 11,
      y: 21,
      attack_range: 3
    }
  end

  defp mob do
    definition = %MobDefinition{
      id: 1_001,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 50,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      skill_range: 7,
      size: :medium,
      race: :plant,
      element: {:water, 1},
      walk_speed: 400,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 300
    }

    spawn = %MobSpawn{
      mob: 1_001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 12, y: 22}
    }

    MobState.new(401, definition, spawn, "prontera", 12, 22)
  end
end
