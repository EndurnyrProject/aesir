defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnAutocounterTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnAutocounter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_from_context
  setup :verify_on_exit!

  describe "cast/4" do
    test "arms sc_auto_counter on the caster for 400 * level ms carrying the level in val1" do
      test_pid = self()
      caster = %PlayerState{character_id: 4001}
      {:ok, definition} = Catalog.by_id(61)

      stub(StatusInterpreter, :apply_status, fn :player, 4001, :sc_auto_counter, params ->
        send(test_pid, {:applied, params})
        :ok
      end)

      assert {:ok, ^caster} = KnAutocounter.cast(caster, :self, 3, definition)

      assert_received {:applied, params}
      assert Keyword.fetch!(params, :val1) == 3
      assert Keyword.fetch!(params, :duration) == 1_200
      assert Keyword.fetch!(params, :caster_id) == 4001
    end

    test "keeps the cast when the counter status is refused" do
      caster = %PlayerState{character_id: 4002}
      {:ok, definition} = Catalog.by_id(61)

      stub(StatusInterpreter, :apply_status, fn :player, 4002, :sc_auto_counter, _params ->
        {:error, :immune}
      end)

      assert {:ok, ^caster} = KnAutocounter.cast(caster, {:unit, 9002}, 5, definition)
    end
  end

  describe "definition" do
    test "both modes allow unarmed and sword counters but not bows" do
      renewal = KnAutocounter.definition(:renewal)
      classic = KnAutocounter.definition(:pre_renewal)

      assert :fist in renewal.require_weapon
      assert :one_handed_sword in renewal.require_weapon
      refute :bow in renewal.require_weapon
      assert classic.require_weapon == renewal.require_weapon
    end
  end
end
