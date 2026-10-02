defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaSacrificeTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaSacrifice
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_from_context
  setup :verify_on_exit!

  @tag game_mode: :renewal
  test "renewal has no after-cast delay" do
    assert {:ok, definition} = Catalog.by_name(:pa_sacrifice)
    assert definition.after_cast_delay == [0, 0, 0, 0, 0]
    assert_cast(definition)
  end

  @tag game_mode: :pre_renewal
  test "classic adds a two second after-cast delay" do
    assert {:ok, definition} = Catalog.by_name(:pa_sacrifice)
    assert definition.after_cast_delay == List.duplicate(2_000, 5)
    assert_cast(definition)
  end

  test "a mob caster is refused" do
    assert {:ok, definition} = Catalog.by_name(:pa_sacrifice)

    assert {:error, :player_only} =
             PaSacrifice.cast(struct(MobState, instance_id: 9), :self, 1, definition)
  end

  defp assert_cast(definition) do
    assert definition.id == 368
    assert definition.sp_cost == List.duplicate(100, 5)
    assert definition.target_type == :self

    player = %PlayerState{character_id: 5_301}

    expect(Interpreter, :apply_status, fn :player, 5_301, :sc_sacrifice, params ->
      assert params[:val1] == 4
      assert params[:caster_id] == 5_301
      refute Keyword.has_key?(params, :duration)
      :ok
    end)

    assert {:ok, ^player} = PaSacrifice.cast(player, :self, 4, definition)
  end
end
