defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkConcentrationTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.LordKnight.LkConcentration
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_from_context
  setup :verify_on_exit!

  @tag game_mode: :renewal
  test "renewal level five applies status for 60 seconds" do
    assert_cast(60_000)
  end

  @tag game_mode: :pre_renewal
  test "classic level five applies status for 45 seconds" do
    assert_cast(45_000)
  end

  defp assert_cast(duration) do
    assert {:ok, definition} = Catalog.by_name(:lk_concentration)
    assert definition.id == 357
    assert definition.sp_cost == [14, 18, 22, 26, 30]
    player = %PlayerState{character_id: 5_001}

    expect(Interpreter, :apply_status, fn :player, 5_001, :sc_concentration, params ->
      assert params[:val1] == 5
      assert params[:duration] == duration
      assert params[:caster_id] == 5_001
      :ok
    end)

    assert {:ok, ^player} = LkConcentration.cast(player, :self, 5, definition)
  end
end
