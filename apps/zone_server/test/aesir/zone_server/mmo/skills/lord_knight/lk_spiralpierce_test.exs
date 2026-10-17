defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkSpiralpierceTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.LordKnight.LkSpiralpierce
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Player.WeaponHand
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "both modes declare five displayed hits" do
    for mode <- [:renewal, :pre_renewal] do
      assert LkSpiralpierce.definition(mode).hit_count == 5
    end
  end

  @tag game_mode: :renewal
  test "Renewal level five uses spear weight, medium size, and base level" do
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    caster = caster(1401)
    stub_weapon(1401, :one_handed_spear)
    assert :ok = LkSpiralpierce.validate(caster, {:unit, 6_160}, 5, definition)

    stub(Combat, :resolve_combatant, fn 6_160 ->
      {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_160, size: :medium)}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, 6_160, opts ->
      assert opts[:weight_atk] == 150
      assert opts[:base_atk_rate] == 80
      assert opts[:skill_ratio] == 400
      assert opts[:hit_divisions] == 5
      assert opts[:skip_crit] == true
      {:ok, %{hit?: false}}
    end)

    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_160}, 5, definition)
  end

  @tag game_mode: :pre_renewal
  test "classic level five raises the weight by level, adds STR and takes its own size fix" do
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    caster = caster(1401)

    caster = %{
      caster
      | stats: %{
          caster.stats
          | base_stats: %{caster.stats.base_stats | str: 50},
            right_hand: spear()
        }
    }

    stub_weapon(1401, :one_handed_spear)
    assert :ok = LkSpiralpierce.validate(caster, {:unit, 6_160}, 5, definition)

    stub(Combat, :resolve_combatant, fn 6_160 ->
      {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_160, size: :small)}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, 6_160, opts ->
      # 1500 * 8 / 100 = 120, raised 250% to 420, + (50 / 10)^2 = 445, small 125%.
      assert opts[:base_damage] == 556
      refute Keyword.has_key?(opts, :skill_ratio)
      assert opts[:ignore_defense] == true
      assert opts[:ignore_size] == true
      # The weapon's refine ATK, not its refine level.
      assert opts[:refine_atk] == 35
      assert opts[:hit_divisions] == 5
      {:ok, %{hit?: false}}
    end)

    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_160}, 5, definition)
  end

  @tag game_mode: :pre_renewal
  test "classic refuses swords before SP is consumed" do
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    stub_weapon(1101, :one_handed_sword)

    assert {:error, :wrong_weapon} =
             LkSpiralpierce.validate(caster(1101), {:unit, 6_160}, 1, definition)
  end

  @tag game_mode: :renewal
  test "Renewal admits a sword wielder" do
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    stub_weapon(1101, :one_handed_sword)
    assert :ok = LkSpiralpierce.validate(caster(1101), {:unit, 6_160}, 1, definition)
  end

  @tag game_mode: :renewal
  test "a level-seven renewal mob row uses neutral long misc-flagged damage without weapon stats" do
    caster = mob([])
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)
    target_ref = {:player, 6_161}

    stub(Combat, :resolve_combatant, fn ^target_ref ->
      {:ok, CombatTestHelper.create_player_combatant(unit_id: 6_161)}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, ^target_ref, opts ->
      assert opts[:skill_id] == 397
      assert opts[:skill_level] == 5
      assert opts[:hit_divisions] == 5
      assert opts[:element] == :neutral
      assert opts[:dmg_type] == :misc
      assert opts[:skip_crit] == true
      refute Keyword.has_key?(opts, :weight_atk)
      refute Keyword.has_key?(opts, :base_damage)
      {:ok, %{hit?: false}}
    end)

    assert :ok =
             LkSpiralpierce.mob_cast(caster, {:unit, :player, 6_161}, 7, definition, %{level: 7})
  end

  @tag game_mode: :pre_renewal
  test "a classic mob row adds the STR bonus and its own size fix to the ordinary base and ignores DEF" do
    caster = mob([], str: 50)
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)

    stub(Combat, :resolve_combatant, fn
      {:player, 6_161} ->
        {:ok, CombatTestHelper.create_player_combatant(unit_id: 6_161)}

      {:player, 6_162} ->
        {:ok, CombatTestHelper.create_player_combatant(unit_id: 6_162, size: :large)}
    end)

    # Classic Attack..Attack2 is 0..0; only the skill's (STR 50 / 10)^2 adds 25.
    expect(Combat, :execute_skill_attack, 2, fn ^caster, {:player, id}, opts ->
      assert opts[:base_damage] == if(id == 6_161, do: 25, else: 18)
      assert opts[:ignore_defense] == true
      assert opts[:dmg_type] == :misc
      assert opts[:element] == :neutral
      refute Keyword.has_key?(opts, :skill_ratio)
      refute Keyword.has_key?(opts, :ignore_size)
      refute Keyword.has_key?(opts, :refine_atk)
      {:ok, %{hit?: false}}
    end)

    assert :ok = LkSpiralpierce.mob_cast(caster, {:unit, :player, 6_161}, 5, definition, %{})
    assert :ok = LkSpiralpierce.mob_cast(caster, {:unit, :player, 6_162}, 5, definition, %{})
  end

  @tag game_mode: :pre_renewal
  test "a classic mob row scales a small target by 125%" do
    caster = mob([], str: 50)
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)

    stub(Combat, :resolve_combatant, fn {:player, 6_161} ->
      {:ok, CombatTestHelper.create_player_combatant(unit_id: 6_161, size: :small)}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, {:player, 6_161}, opts ->
      # Zero ordinary ATK + (STR 50 / 10)^2 = 25; small size floors 25 * 125% to 31.
      assert opts[:base_damage] == 31
      {:ok, %{hit?: false}}
    end)

    assert :ok = LkSpiralpierce.mob_cast(caster, {:unit, :player, 6_161}, 5, definition, %{})
  end

  @tag game_mode: :renewal
  test "a renewal mob row keeps the ordinary base at the level ratio with the misc flag" do
    caster = mob([])
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)

    stub(Combat, :resolve_combatant, fn {:player, 6_161} ->
      {:ok, CombatTestHelper.create_player_combatant(unit_id: 6_161)}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, {:player, 6_161}, opts ->
      assert opts[:skill_ratio] == 400
      assert opts[:dmg_type] == :misc
      assert opts[:element] == :neutral
      refute Keyword.has_key?(opts, :base_damage)
      refute Keyword.has_key?(opts, :ignore_defense)
      {:ok, %{hit?: false}}
    end)

    assert :ok = LkSpiralpierce.mob_cast(caster, {:unit, :player, 6_161}, 5, definition, %{})
  end

  test "a landed strike immobilises a player target with Ankle for one second" do
    caster = mob([])
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)

    stub(Combat, :resolve_combatant, fn {:player, 6_161} ->
      {:ok, CombatTestHelper.create_player_combatant(unit_id: 6_161)}
    end)

    stub(Combat, :execute_skill_attack, fn _caster, _target, _opts ->
      {:ok, %{hit?: true, target_survives?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :player, 6_161, :sc_ankle, params ->
      assert params[:duration] == 1_000
      assert params[:caster_id] == 6_160
      assert params[:source_type] == :mob
      refute Keyword.has_key?(params, :bypass_resistance)
      {:ok, :applied}
    end)

    assert :ok = LkSpiralpierce.mob_cast(caster, {:unit, :player, 6_161}, 5, definition, %{})
  end

  test "status-immune mobs, killed targets and homunculi are never immobilised" do
    caster = caster(1401)
    stub_weapon(1401, :one_handed_spear)
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)

    stub(Combat, :resolve_combatant, fn
      6_160 ->
        {:ok,
         CombatTestHelper.create_mob_combatant(unit_id: 6_160, class: :normal)
         |> Map.put(:status_immune, true)}

      6_161 ->
        {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_161, class: :normal)}

      6_162 ->
        {:ok,
         CombatTestHelper.create_mob_combatant(unit_id: 6_162, class: :normal)
         |> Map.put(:unit_type, :homunculus)}
    end)

    stub(Combat, :execute_skill_attack, fn _caster, target_id, _opts ->
      {:ok, %{hit?: true, target_survives?: target_id != 6_161}}
    end)

    reject(&StatusInterpreter.apply_status/4)

    for target_id <- [6_160, 6_161, 6_162] do
      assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, target_id}, 5, definition)
    end
  end

  test "a landed strike immobilises a normal mob with Ankle for one second" do
    target = mob([])
    :ok = UnitRegistry.register_unit(:mob, target.instance_id, MobState, target, self())
    caster = caster(1401)
    stub_weapon(1401, :one_handed_spear)
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)

    stub(Combat, :resolve_combatant, fn 6_160 ->
      {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_160, class: :normal)}
    end)

    stub(Combat, :execute_skill_attack, fn _caster, 6_160, _opts -> {:ok, %{hit?: true}} end)

    :rand.seed(:exsss, {2, 3, 4})
    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_160}, 5, definition)

    assert %{expires_at: expiry, started_at: start} =
             StatusStorage.get_status(:mob, 6_160, :sc_ankle)

    assert expiry - start == 1_000
  end

  test "status-immune monsters and missed hits are never rooted" do
    caster = caster(1401)
    stub_weapon(1401, :one_handed_spear)
    {:ok, definition} = Catalog.by_name(:lk_spiralpierce)

    stub(Combat, :resolve_combatant, fn
      6_160 ->
        {:ok,
         %{
           CombatTestHelper.create_mob_combatant(unit_id: 6_160, class: :boss)
           | status_immune: true
         }}

      6_161 ->
        {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_161, class: :normal)}
    end)

    stub(Combat, :execute_skill_attack, fn _caster, target_id, _opts ->
      {:ok, %{hit?: target_id == 6_160}}
    end)

    reject(&StatusInterpreter.apply_status/4)
    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_160}, 5, definition)
    assert {:ok, ^caster} = LkSpiralpierce.cast(caster, {:unit, 6_161}, 5, definition)
  end

  defp caster(nameid) do
    row = %InventoryItem{nameid: nameid, amount: 1, refine: 7, equip: 2, identify: 1}

    %PlayerState{
      character_id: 5_160,
      inventory: %{0 => row},
      stats: %Stats{
        base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        equipment: %Equipment{right_hand: nameid},
        progression: %PlayerProgression{base_level: 99, job_id: 7}
      }
    }
  end

  defp spear do
    %WeaponHand{
      item_id: 1401,
      subtype: :one_handed_spear,
      element: :neutral,
      base_atk: 100,
      weapon_level: 4,
      refine_atk: 35,
      overrefine_band: 0,
      slot: :right_hand
    }
  end

  defp mob(modes, stats \\ []) do
    data = %MobDefinition{
      id: 1002,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 10,
      hp: 100,
      stats: Map.merge(%{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1}, Map.new(stats)),
      attack_range: 1,
      size: :medium,
      race: :brute,
      element: {:earth, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      modes: modes
    }

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 150, y: 150}
    }

    MobState.new(6_160, data, spawn, "prontera", 150, 150)
  end

  defp stub_weapon(id, subtype) do
    stub(ItemManagement, :get_item_by_id, fn ^id ->
      {:ok,
       %ItemDefinition{
         id: id,
         aegis_name: "test_weapon",
         name: "Test Weapon",
         type: :weapon,
         subtype: subtype,
         weight: 1_500
       }}
    end)
  end
end
