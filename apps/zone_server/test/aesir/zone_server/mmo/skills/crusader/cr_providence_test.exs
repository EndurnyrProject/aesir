defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrProvidenceTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrProvidence
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  defp definition do
    {:ok, definition} = Catalog.by_name(:cr_providence)
    definition
  end

  defp player_state(job_id) do
    struct(PlayerState, %{
      character_id: 1,
      stats: %{progression: %{job_id: job_id}}
    })
  end

  describe "catalog registration" do
    test "Catalog.by_id/1 resolves cr_providence" do
      assert {:ok, definition} = Catalog.by_id(256)
      assert definition.name == :cr_providence
      assert definition.max_level == 5
      assert definition.target_type == :target_ally
      assert definition.sp_cost == [30, 30, 30, 30, 30]
      assert definition.duration == [180_000, 180_000, 180_000, 180_000, 180_000]
    end

    test "Catalog.active_module_for/1 resolves cr_providence" do
      assert {:ok, CrProvidence} = Catalog.active_module_for(:cr_providence)
    end
  end

  describe "validate/4" do
    test "refuses a Crusader-class target" do
      caster = %{character_id: 1000}
      target_id = 2000

      stub(UnitRegistry, :get_unit, fn :player, ^target_id ->
        {:ok, {PlayerState, player_state(14), self()}}
      end)

      assert {:error, :cannot_target_crusader} =
               CrProvidence.validate(caster, {:unit, target_id}, 1, definition())
    end

    test "refuses a Paladin-class target" do
      caster = %{character_id: 1000}
      target_id = 2001

      stub(UnitRegistry, :get_unit, fn :player, ^target_id ->
        {:ok, {PlayerState, player_state(4015), self()}}
      end)

      assert {:error, :cannot_target_crusader} =
               CrProvidence.validate(caster, {:unit, target_id}, 1, definition())
    end

    test "refuses self when the caster is Crusader-class" do
      caster = %{character_id: 3000}

      stub(UnitRegistry, :get_unit, fn :player, 3000 ->
        {:ok, {PlayerState, player_state(14), self()}}
      end)

      assert {:error, :cannot_target_crusader} =
               CrProvidence.validate(caster, :self, 1, definition())
    end

    test "allows a non-Crusader ally" do
      caster = %{character_id: 1000}
      target_id = 2002

      stub(UnitRegistry, :get_unit, fn :player, ^target_id ->
        {:ok, {PlayerState, player_state(7), self()}}
      end)

      assert :ok = CrProvidence.validate(caster, {:unit, target_id}, 1, definition())
    end

    test "allows a mob target" do
      caster = %{character_id: 1000}
      target_id = 2003
      stub(UnitRegistry, :get_unit, fn :player, ^target_id -> {:error, :not_found} end)

      assert :ok = CrProvidence.validate(caster, {:unit, target_id}, 1, definition())
    end
  end

  describe "cast/4" do
    test "applies sc_providence to a player ally at level 1" do
      caster = %{character_id: 1000}
      target_id = 2000
      stub(UnitRegistry, :unit_exists?, fn :mob, ^target_id -> false end)

      expect(StatusInterpreter, :apply_status, fn :player, ^target_id, :sc_providence, params ->
        assert params[:val1] == 1
        assert params[:caster_id] == 1000
        assert params[:duration] == 180_000
        :ok
      end)

      assert {:ok, ^caster} = CrProvidence.cast(caster, {:unit, target_id}, 1, definition())
    end

    test "applies sc_providence to a mob at level 5" do
      caster = %{character_id: 1000}
      target_id = 2001
      stub(UnitRegistry, :unit_exists?, fn :mob, ^target_id -> true end)

      expect(StatusInterpreter, :apply_status, fn :mob, ^target_id, :sc_providence, params ->
        assert params[:val1] == 5
        assert params[:duration] == 180_000
        :ok
      end)

      assert {:ok, ^caster} = CrProvidence.cast(caster, {:unit, target_id}, 5, definition())
    end

    test "propagates an error from StatusInterpreter" do
      caster = %{character_id: 1000}
      target_id = 2002
      stub(UnitRegistry, :unit_exists?, fn :mob, ^target_id -> false end)

      expect(StatusInterpreter, :apply_status, fn :player, ^target_id, :sc_providence, _params ->
        {:error, :already_applied}
      end)

      assert {:error, :already_applied} =
               CrProvidence.cast(caster, {:unit, target_id}, 1, definition())
    end
  end
end
