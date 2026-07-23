defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnAutocounterTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnAutocounter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :set_mimic_from_context
  setup :verify_on_exit!

  describe "cast/4" do
    test "arms sc_auto_counter on the caster for 400 * level ms carrying the level in val1" do
      test_pid = self()
      caster = %{character_id: 4001}
      {:ok, definition} = Catalog.by_id(61)

      stub(StatusInterpreter, :apply_status, fn :player, 4001, :sc_auto_counter, params ->
        send(test_pid, {:applied, params})
        :ok
      end)

      assert {:ok, ^caster} = KnAutocounter.cast(caster, {:unit, 9001}, 3, definition)

      assert_received {:applied, params}
      assert Keyword.fetch!(params, :val1) == 3
      assert Keyword.fetch!(params, :duration) == 1_200
      assert Keyword.fetch!(params, :caster_id) == 4001
    end

    test "propagates an application failure" do
      caster = %{character_id: 4002}
      {:ok, definition} = Catalog.by_id(61)

      stub(StatusInterpreter, :apply_status, fn :player, 4002, :sc_auto_counter, _params ->
        {:error, :immune}
      end)

      assert {:error, :immune} = KnAutocounter.cast(caster, {:unit, 9002}, 5, definition)
    end
  end

  describe "definition" do
    test "is registered in the catalog with the Knight skill metadata" do
      assert {:ok, definition} = Catalog.by_id(61)
      assert definition.name == :kn_autocounter
      assert definition.max_level == 5
      assert definition.target_type == :target_enemy
      assert Enum.all?(definition.sp_cost, &(&1 == 3))
    end
  end
end
