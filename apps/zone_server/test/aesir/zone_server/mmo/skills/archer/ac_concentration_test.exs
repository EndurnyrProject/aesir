defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcConcentrationTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Archer.AcConcentration
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    stub(UnitRegistry, :get_unit, fn
      :player, player_id ->
        state = %PlayerState{
          character_id: player_id,
          action_state: :idle,
          stats: %{current_state: %{hp: 1}}
        }

        {:ok, {PlayerState, state, self()}}

      :mob, mob_id ->
        state = struct(MobState, %{instance_id: mob_id, hp: 1, is_dead: false})
        {:ok, {MobState, state, self()}}
    end)

    :ok
  end

  @caster %{
    character_id: 1000,
    stats: %Stats{modifiers: %Stats.Modifiers{equipment: %{agi: 5, dex: 3}}}
  }

  describe "skill data" do
    test "ac_concentration loads from the catalog as a self no-damage buff" do
      assert {:ok, definition} = Catalog.by_id(45)
      assert {:ok, ^definition} = Catalog.by_name(:ac_concentration)
      assert definition.name == :ac_concentration
      assert definition.display_name == "Improve Concentration"
      assert definition.target_type == :self
      assert definition.damage_type == :no_damage
      assert definition.max_level == 10
      assert definition.sp_cost == [25, 30, 35, 40, 45, 50, 55, 60, 65, 70]
    end

    test "is registered as an active skill" do
      assert {:ok, AcConcentration} = Catalog.active_module_for(:ac_concentration)
    end
  end

  describe "cast/4 status application" do
    setup do
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:error, :not_found} end)
      :ok
    end

    test "applies sc_concentrate with val2 = 2 + level and the level-1 duration" do
      expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_concentrate, params ->
        assert params[:val1] == 1
        assert params[:val2] == 3
        assert params[:duration] == 60_000
        assert params[:caster_id] == 1000
        :ok
      end)

      assert {:ok, @caster} =
               AcConcentration.cast(@caster, :self, 1, AcConcentration.definition())
    end

    test "scales val2 and duration with level (lv10 -> val2 12, duration 240_000)" do
      expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_concentrate, params ->
        assert params[:val2] == 12
        assert params[:duration] == 240_000
        :ok
      end)

      assert {:ok, _} = AcConcentration.cast(@caster, :self, 10, AcConcentration.definition())
    end

    test "excludes the caster's equipment AGI/DEX bonus via val3/val4" do
      expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_concentrate, params ->
        assert params[:val3] == 5
        assert params[:val4] == 3
        :ok
      end)

      assert {:ok, _} = AcConcentration.cast(@caster, :self, 1, AcConcentration.definition())
    end

    test "propagates an apply failure and skips the reveal" do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_concentrate, _ ->
        {:error, :immune}
      end)

      reject(&SpatialIndex.get_all_units_in_range/4)
      reject(&Helpers.remove_statuses/2)

      assert {:error, :immune} =
               AcConcentration.cast(@caster, :self, 1, AcConcentration.definition())
    end
  end

  describe "cast/4 reveal pulse" do
    test "removes sc_hiding/sc_cloaking from units within radius 3 of the caster" do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_concentrate, _ -> :ok end)

      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:ok, {150, 150, "prontera"}} end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 3 ->
        [{:player, 2000}, {:mob, 3000}]
      end)

      expect(Helpers, :remove_statuses, 2, fn target, [:sc_hiding, :sc_cloaking] ->
        assert target in [{:player, 2000}, {:mob, 3000}]
        :ok
      end)

      assert {:ok, _} = AcConcentration.cast(@caster, :self, 1, AcConcentration.definition())
    end

    test "is a no-op when the caster position cannot be resolved" do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_concentrate, _ -> :ok end)
      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:error, :not_found} end)
      reject(&SpatialIndex.get_all_units_in_range/4)
      reject(&Helpers.remove_statuses/2)

      assert {:ok, _} = AcConcentration.cast(@caster, :self, 1, AcConcentration.definition())
    end

    test "does not reveal a corpse" do
      corpse = %PlayerState{
        character_id: 2000,
        action_state: :dead,
        stats: %{current_state: %{hp: 0}}
      }

      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_concentrate, _ -> :ok end)

      stub(SpatialIndex, :get_unit_position, fn :player, 1000 -> {:ok, {150, 150, "prontera"}} end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, 3 ->
        [{:player, 2000}]
      end)

      stub(UnitRegistry, :get_unit, fn :player, 2000 -> {:ok, {PlayerState, corpse, self()}} end)
      reject(&Helpers.remove_statuses/2)

      assert {:ok, _} = AcConcentration.cast(@caster, :self, 1, AcConcentration.definition())
    end
  end
end
