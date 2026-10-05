defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgStonecurseTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgStonecurse
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

  describe "metadata" do
    test "classic casts slower and petrifies for longer" do
      assert MgStonecurse.definition(:renewal).cast_time == List.duplicate(800, 10)
      assert MgStonecurse.definition(:pre_renewal).cast_time == List.duplicate(1000, 10)

      assert MgStonecurse.definition(:renewal).duration == List.duplicate(17_000, 10)
      assert MgStonecurse.definition(:pre_renewal).duration == List.duplicate(20_000, 10)
    end
  end

  describe "cast/4" do
    setup do
      stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
      stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
      :ok
    end

    test "starts the petrification wait with one combined chance and consumes the gem" do
      caster = caster()

      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stonewait, params ->
        assert params[:val1] == 4
        assert params[:success_rate] == 36
        assert params[:state] == %{delay: 5_000}
        :ok
      end)

      assert {:ok, ^caster} = MgStonecurse.cast(caster, {:unit, @target_id}, 4, definition())
    end

    @tag game_mode: :renewal
    test "the status lasts 17 seconds in renewal, wait phase included" do
      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stonewait, params ->
        assert params[:duration] == 17_000
        :ok
      end)

      assert {:ok, _} = MgStonecurse.cast(caster(), {:unit, @target_id}, 4, definition())
    end

    @tag game_mode: :pre_renewal
    test "the status lasts 20 seconds in classic, wait phase included" do
      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stonewait, params ->
        assert params[:duration] == 20_000
        :ok
      end)

      assert {:ok, _} = MgStonecurse.cast(caster(), {:unit, @target_id}, 4, definition())
    end

    test "consumes the gem on failure at level <= 5" do
      caster = caster()

      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stonewait, _params ->
        {:error, :resisted}
      end)

      assert {:ok, ^caster} = MgStonecurse.cast(caster, {:unit, @target_id}, 5, definition())
    end

    test "keeps the gem on failure at level >= 6" do
      caster = caster()

      expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stonewait, _params ->
        {:error, :resisted}
      end)

      assert {:ok, ^caster, :no_consume} =
               MgStonecurse.cast(caster, {:unit, @target_id}, 6, definition())
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
      # The caster's character_id is deliberately not registered as a mob:
      # ContextBuilder used to resolve the caster with the *target's* unit type
      # and raise on the missing unit.
      caster = caster()

      assert {:ok, ^caster} = MgStonecurse.cast(caster, {:unit, @target_id}, 4, definition())

      assert %{val1: 4, source_id: 1000, source_type: :player} =
               StatusStorage.get_status(:mob, @target_id, :sc_stonewait)
    end
  end
end
