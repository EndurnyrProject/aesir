defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHealTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SkillHeal
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  @ally_id 2000

  setup do
    Mimic.copy(SkillHeal)

    caster =
      PlayerState.new(%Character{
        id: 1000,
        account_id: 1000,
        name: "Healer",
        class: 4,
        sex: "M",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 50,
        hp: 100,
        sp: 100
      })

    stub(Combat, :resolve_combatant, fn _ ->
      {:ok, PlayerState.to_combatant(%{caster | character_id: @ally_id})}
    end)

    stub(SkillHeal, :amount, fn _caster, _target, 28, 5, heal? ->
      if heal?, do: 350, else: 200
    end)

    {:ok, definition} = Catalog.by_id(28)
    {:ok, caster: caster, definition: definition}
  end

  describe "cast/4 — player/ally target" do
    test "healing self calls apply_heal on caster_id with the computed amount",
         %{caster: caster, definition: definition} do
      expect(SkillHeal, :amount, fn %{player?: true}, {:player, 1000}, 28, 5, true -> 350 end)
      expect(Combat, :apply_heal, fn :player, 1000, 350, 1000 -> :ok end)

      assert {:ok, ^caster} = AlHeal.cast(caster, :self, 5, definition)
    end

    test "healing an ally calls apply_heal on target_id with source_id",
         %{caster: caster, definition: definition} do
      expect(SkillHeal, :amount, fn %{player?: true}, {:player, @ally_id}, 28, 5, true -> 350 end)
      expect(Combat, :apply_heal, fn :player, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, ^caster} = AlHeal.cast(caster, {:unit, @ally_id}, 5, definition)
    end
  end

  describe "cast/4 — target unit type is resolved generically" do
    test "a mob target calls apply_heal with :mob, not the hardcoded :player",
         %{caster: caster, definition: definition} do
      stub(UnitRegistry, :unit_exists?, fn :mob, @ally_id -> true end)
      expect(SkillHeal, :amount, fn %{player?: true}, {:mob, @ally_id}, 28, 5, true -> 350 end)
      expect(Combat, :apply_heal, fn :mob, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, ^caster} = AlHeal.cast(caster, {:unit, @ally_id}, 5, definition)
    end

    test "a typed Homunculus target remains exact despite a same-number mob",
         %{caster: caster, definition: definition} do
      mob = %{mob_caster(base_level: 50, int: 50, matk: 50) | instance_id: @ally_id}
      :ok = UnitRegistry.register_unit(:mob, @ally_id, MobState, mob, self())

      homunculus = %HomunculusState{
        id: 1,
        world_gid: @ally_id,
        owner_character_id: caster.character_id,
        class_id: 6001,
        name: "Lif"
      }

      friendly = HomunculusState.to_combatant(homunculus)

      expect(Combat, :resolve_combatant, fn {:homunculus, @ally_id} ->
        {:ok, friendly}
      end)

      expect(SkillHeal, :amount, fn %{player?: true}, {:homunculus, @ally_id}, 28, 5, true ->
        350
      end)

      expect(Combat, :apply_heal, fn :homunculus, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, ^caster} =
               AlHeal.cast(caster, {:unit, {:homunculus, @ally_id}}, 5, definition)
    end
  end

  describe "cast/4 — undead target deals holy damage instead of healing" do
    test "an undead-element enemy takes a holy magic attack on the strike amount, not apply_heal",
         %{caster: caster, definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :undead, element: {:undead, 1}})}
      end)

      reject(&Combat.apply_heal/4)

      expect(Combat, :execute_magic_attack, fn _caster, @ally_id, opts ->
        assert Enum.sort(opts) ==
                 Enum.sort(
                   skill_id: 28,
                   skill_level: 5,
                   element: :holy,
                   base_damage: 200,
                   ignore_mdef: true,
                   skip_range: true
                 )

        {:ok, {:mob, @ally_id}}
      end)

      assert {:ok, ^caster} = AlHeal.cast(caster, {:unit, @ally_id}, 5, definition)
    end

    test "an undead defense element makes any race an offensive target",
         %{caster: caster, definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :demi_human, element: {:undead, 1}})}
      end)

      expect(Combat, :execute_magic_attack, fn _caster, @ally_id, opts ->
        assert opts[:base_damage] == 200
        {:ok, {:mob, @ally_id}}
      end)

      assert {:ok, ^caster} = AlHeal.cast(caster, {:unit, @ally_id}, 5, definition)
    end

    test "a demon-race target that is not undead is healed, not damaged",
         %{caster: caster, definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :demon, element: {:dark, 1}})}
      end)

      expect(Combat, :apply_heal, fn :player, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, ^caster} = AlHeal.cast(caster, {:unit, @ally_id}, 5, definition)
    end

    test "an undead-race target with no undead element is healed, not damaged",
         %{caster: caster, definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok, enemy(%{race: :undead, element: {:ghost, 1}})}
      end)

      expect(Combat, :apply_heal, fn :player, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, ^caster} = AlHeal.cast(caster, {:unit, @ally_id}, 5, definition)
    end

    test "an undead-element target friendly to the caster is healed, not damaged",
         %{caster: caster, definition: definition} do
      stub(Combat, :resolve_combatant, fn _id ->
        {:ok,
         %{PlayerState.to_combatant(%{caster | character_id: @ally_id}) | element: {:undead, 1}}}
      end)

      expect(Combat, :apply_heal, fn :player, @ally_id, 350, 1000 -> :ok end)

      assert {:ok, ^caster} = AlHeal.cast(caster, {:unit, @ally_id}, 5, definition)
    end
  end

  test "the recipe receives effective INT rather than only allocated INT",
       %{caster: caster, definition: definition} do
    caster = put_in(caster.stats.base_stats.int, 40)
    caster = put_in(caster.stats.modifiers.job_bonuses, %{int: 5})
    caster = put_in(caster.stats.modifiers.equipment, %{int: 6, all_stats: 3})
    caster = put_in(caster.stats.modifiers.status_effects, %{int: 7})
    caster = put_in(caster.stats.modifiers.passive, %{int: 2})

    expect(SkillHeal, :amount, fn %{player?: true, int: 63}, {:player, 1000}, 28, 5, true ->
      731
    end)

    expect(Combat, :apply_heal, fn :player, 1000, 731, 1000 -> :ok end)

    assert {:ok, ^caster} = AlHeal.cast(caster, :self, 5, definition)
  end

  test "a mob caster supplies its own stats and source id", %{definition: definition} do
    mob = mob_caster(base_level: 50, int: 50, matk: 50)

    expect(SkillHeal, :amount, fn %{player?: false, base_level: 50, int: 50},
                                  {:player, @ally_id},
                                  28,
                                  5,
                                  true ->
      731
    end)

    expect(Combat, :apply_heal, fn :player, @ally_id, 731, 9001 -> :ok end)

    assert {:ok, ^mob} = AlHeal.cast(mob, {:unit, @ally_id}, 5, definition)
  end

  test "only a player's Heal strikes: a monster heals an undead enemy", %{definition: definition} do
    mob = mob_caster(base_level: 50, int: 50, matk: 50)

    stub(Combat, :resolve_combatant, fn _id ->
      {:ok,
       enemy(%{
         race: :undead,
         element: {:undead, 1},
         unit_type: :player,
         social_root: {:player, @ally_id}
       })}
    end)

    reject(&Combat.execute_magic_attack/3)
    expect(Combat, :apply_heal, fn :player, @ally_id, 350, 9001 -> :ok end)

    assert {:ok, ^mob} = AlHeal.cast(mob, {:unit, @ally_id}, 5, definition)
  end

  defp enemy(attrs) do
    mob = %{mob_caster(base_level: 50, int: 50, matk: 50) | instance_id: @ally_id}
    struct(MobState.to_combatant(mob), attrs)
  end

  defp mob_caster(opts) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "test_healer",
      name: "Test Healer",
      level: Keyword.fetch!(opts, :base_level),
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 1, int: Keyword.fetch!(opts, :int), dex: 1, luk: 1},
      matk: Keyword.fetch!(opts, :matk),
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9001, mob_data, spawn_ref, "prontera", 100, 100)
  end
end
