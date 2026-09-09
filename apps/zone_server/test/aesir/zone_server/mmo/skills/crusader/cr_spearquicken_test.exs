defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrSpearquickenTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrSpearquicken
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  setup :set_mimic_private
  setup :verify_on_exit!

  @caster_id 3000
  @one_handed_spear_id 1401
  @two_handed_spear_id 1410
  @dagger_id 1201

  defp definition do
    {:ok, definition} = Catalog.by_id(258)
    definition
  end

  defp caster(weapon_id \\ nil) do
    inventory =
      if weapon_id do
        item = %InventoryItem{nameid: weapon_id, amount: 1, equip: 0, identify: 1}

        assert {:ok, inventory, {:equipped, 0, _mask, []}} =
                 Inventory.equip(%{0 => item}, 0, 2, %{job_id: 14, base_level: 70})

        inventory
      else
        %{}
      end

    %PlayerState{
      character_id: @caster_id,
      inventory: inventory,
      stats: %Stats{
        equipment: Stats.equipment_from_inventory(Map.values(inventory)),
        progression: %PlayerProgression{base_level: 70, job_level: 40, job_id: 14}
      }
    }
  end

  defp mob_caster do
    mob_data = %MobDefinition{
      id: 1004,
      aegis_name: "test_crusader",
      name: "Test Crusader",
      level: 50,
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      matk: 0,
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
      mob: 1004,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9003, mob_data, spawn_ref, "prontera", 100, 100)
  end

  describe "catalog registration" do
    test "by_id(258) resolves cr_spearquicken" do
      assert {:ok, definition} = Catalog.by_id(258)
      assert definition.name == :cr_spearquicken
      assert definition.display_name == "Spear Quicken"
      assert definition.max_level == 10
      assert definition.target_type == :self
    end

    test "by_name/1 resolves the atom" do
      assert {:ok, %{id: 258}} = Catalog.by_name(:cr_spearquicken)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, CrSpearquicken} = Catalog.active_module_for(:cr_spearquicken)
    end
  end

  describe "metadata" do
    test "sp_cost and duration match the per-level tables" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)

      assert definition.sp_cost == [24, 28, 32, 36, 40, 44, 48, 52, 56, 60]

      assert definition.duration ==
               [
                 30_000,
                 60_000,
                 90_000,
                 120_000,
                 150_000,
                 180_000,
                 210_000,
                 240_000,
                 270_000,
                 300_000
               ]
    end
  end

  describe "validate/4 (player weapon gate)" do
    test "rejects a cast without a spear equipped" do
      assert {:error, :requires_spear} =
               CrSpearquicken.validate(
                 caster(@dagger_id),
                 :self,
                 1,
                 definition()
               )
    end

    test "rejects a bare-handed cast" do
      assert {:error, :requires_spear} = CrSpearquicken.validate(caster(), :self, 1, definition())
    end

    @tag game_mode: :renewal
    test "allows a cast with a one-handed spear equipped" do
      assert :ok =
               CrSpearquicken.validate(
                 caster(@one_handed_spear_id),
                 :self,
                 1,
                 definition()
               )
    end

    @tag game_mode: :pre_renewal
    test "classic refuses a one-handed spear and lists only the two-handed spear" do
      {:ok, definition} = Catalog.by_id(258)
      assert definition.require_weapon == [:two_handed_spear]

      caster = caster(@one_handed_spear_id)
      assert {:error, :requires_spear} = CrSpearquicken.validate(caster, :self, 1, definition)
    end

    test "allows a cast with a two-handed spear equipped" do
      assert :ok =
               CrSpearquicken.validate(
                 caster(@two_handed_spear_id),
                 :self,
                 1,
                 definition()
               )
    end
  end

  describe "validate/4 (mob caster bypass)" do
    test "always allows a mob caster regardless of weapon" do
      assert :ok = CrSpearquicken.validate(mob_caster(), :self, 1, definition())
    end
  end

  describe "cast/4" do
    test "lv1 applies sc_spearquicken with val1=1, val2=7 and the tabulated duration" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)
      caster = caster(@one_handed_spear_id)

      expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_spearquicken, params ->
        assert params[:val1] == 1
        assert params[:val2] == 7
        assert params[:caster_id] == @caster_id
        assert params[:duration] == 30_000
        :ok
      end)

      assert {:ok, ^caster} = CrSpearquicken.cast(caster, :self, 1, definition)
    end

    test "lv10 applies sc_spearquicken with val1=10, val2=7 and the tabulated duration" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)
      caster = caster(@two_handed_spear_id)

      expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_spearquicken, params ->
        assert params[:val1] == 10
        assert params[:val2] == 7
        assert params[:duration] == 300_000
        :ok
      end)

      assert {:ok, ^caster} = CrSpearquicken.cast(caster, :self, 10, definition)
    end

    test "a mistargeted {:unit, id} row still buffs the caster, not the given id" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)
      caster = caster(@one_handed_spear_id)

      expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_spearquicken, params ->
        assert params[:val1] == 4
        assert params[:caster_id] == @caster_id
        :ok
      end)

      assert {:ok, ^caster} = CrSpearquicken.cast(caster, {:unit, 999_999}, 4, definition)
    end

    test "a mob caster self-applies through :mob, not :player" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)
      mob = mob_caster()

      expect(StatusInterpreter, :apply_status, fn :mob, 9003, :sc_spearquicken, params ->
        assert params[:val1] == 5
        assert params[:val2] == 7
        assert params[:caster_id] == 9003
        assert params[:duration] == 150_000
        :ok
      end)

      assert {:ok, ^mob} = CrSpearquicken.cast(mob, :self, 5, definition)
    end
  end
end
