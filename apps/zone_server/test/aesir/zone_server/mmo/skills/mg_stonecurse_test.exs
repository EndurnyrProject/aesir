defmodule Aesir.ZoneServer.Mmo.Skills.MgStonecurseTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.MgStonecurse
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @target_id 2000

  defp caster, do: %PlayerState{character_id: 1000}

  defp definition do
    {:ok, definition} = Catalog.by_name(:mg_stonecurse)
    definition
  end

  describe "catalog registration" do
    test "by_id/1 resolves id 16" do
      assert {:ok, %{name: :mg_stonecurse}} = Catalog.by_id(16)
    end

    test "by_name/1 resolves the atom" do
      assert {:ok, %{id: 16}} = Catalog.by_name(:mg_stonecurse)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, MgStonecurse} = Catalog.active_module_for(:mg_stonecurse)
    end
  end

  describe "metadata" do
    test "matches the rAthena renewal table" do
      definition = definition()

      assert definition.max_level == 10
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :no_damage
      assert definition.element == :earth
      assert definition.range == 2
      assert definition.cast_time == List.duplicate(800, 10)
      assert definition.fixed_cast_time == List.duplicate(200, 10)
      assert definition.sp_cost == [25, 24, 23, 22, 21, 20, 19, 18, 17, 16]
      assert definition.item_cost == [%{id: 716, amount: 1}]
    end
  end

  describe "cast/4" do
    test "applies sc_stone and consumes the gem when the roll succeeds" do
      # Seed {1,2,3} yields :rand.uniform(100) == 27, below every success chance.
      :rand.seed(:exsss, {1, 2, 3})
      caster = caster()
      definition = definition()

      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stone, params ->
        assert params[:val1] == 4
        :ok
      end)

      assert {:ok, ^caster} = MgStonecurse.cast(caster, {:unit, @target_id}, 4, definition)
    end

    test "consumes the gem on failure at level <= 5" do
      # Seed {6,7,8} yields :rand.uniform(100) == 87, above the level-5 chance (40).
      :rand.seed(:exsss, {6, 7, 8})
      caster = caster()
      definition = definition()

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = MgStonecurse.cast(caster, {:unit, @target_id}, 5, definition)
    end

    test "keeps the gem on failure at level >= 6" do
      # Seed {6,7,8} yields :rand.uniform(100) == 87, above the level-6 chance (44).
      :rand.seed(:exsss, {6, 7, 8})
      caster = caster()
      definition = definition()

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster, :no_consume} =
               MgStonecurse.cast(caster, {:unit, @target_id}, 6, definition)
    end
  end

  describe "cast/4 against a live mob (real apply_status, no boundary stub)" do
    setup :setup_ets_tables

    setup do
      Mimic.copy(Resistance)

      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)

      stub(UnitRegistry, :get_unit_info, fn
        :mob, @target_id ->
          {:ok,
           %{
             unit_id: @target_id,
             unit_type: :mob,
             race: :formless,
             element: :neutral,
             element_level: 1,
             boss_flag: false,
             size: :medium,
             stats: %{
               max_hp: 1000,
               hp: 1000,
               level: 10,
               base_level: 10,
               str: 10,
               agi: 10,
               vit: 10,
               int: 10,
               dex: 10,
               luk: 10,
               mdef: 5
             }
           }}

        _unit_type, _unit_id ->
          {:error, :not_found}
      end)

      stub(Resistance, :roll_success, fn _success_rate -> true end)
      :ok
    end

    test "petrifies the mob without crashing on the player caster id" do
      # Seed {1,2,3} yields :rand.uniform(100) == 27, below every success chance.
      # The caster's character_id is deliberately not registered as a mob:
      # ContextBuilder used to resolve the caster with the *target's* unit type
      # and raise on the missing unit.
      :rand.seed(:exsss, {1, 2, 3})
      caster = caster()

      assert {:ok, ^caster} = MgStonecurse.cast(caster, {:unit, @target_id}, 4, definition())

      assert %{val1: 4, source_id: 1000, source_type: :player} =
               StatusStorage.get_status(:mob, @target_id, :sc_stone)
    end
  end
end
