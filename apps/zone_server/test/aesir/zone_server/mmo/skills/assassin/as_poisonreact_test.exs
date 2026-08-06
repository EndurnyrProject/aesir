defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsPoisonreactTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsPoisonreact
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  test "defines the canonical Poison React contract" do
    assert {:ok, definition} = Catalog.by_id(139)
    assert definition.name == :as_poisonreact
    assert definition.display_name == "Poison React"
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.sp_cost == [25, 30, 35, 40, 45, 50, 55, 60, 45, 45]

    assert definition.duration ==
             [20_000, 25_000, 30_000, 35_000, 40_000, 45_000, 50_000, 55_000, 60_000, 60_000]
  end

  test "arms block mode with level-derived charges and a 50 percent chance" do
    caster = %PlayerState{character_id: 1_001}
    definition = AsPoisonreact.definition()

    expect(StatusInterpreter, :apply_status, fn :player, 1_001, :sc_poisonreact, params ->
      assert params[:val1] == 7
      assert params[:duration] == 50_000
      assert params[:caster_id] == 1_001
      assert params[:source_type] == :player
      :ok
    end)

    assert {:ok, ^caster} = AsPoisonreact.cast(caster, :self, 7, definition)
  end
end
