defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgSightTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgSight
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  @caster %PlayerState{character_id: 1000}

  describe "cast/4" do
    test "applies sc_sight to the caster for 10 seconds" do
      expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_sight, params ->
        assert params[:duration] == 10_000
        assert params[:caster_id] == 1000
        :ok
      end)

      assert {:ok, @caster} = MgSight.cast(@caster, :self, 1, MgSight.definition())
    end

    test "propagates an apply failure" do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_sight, _ ->
        {:error, :immune}
      end)

      assert {:error, :immune} = MgSight.cast(@caster, :self, 1, MgSight.definition())
    end
  end
end
