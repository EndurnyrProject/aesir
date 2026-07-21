defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoSteelbodyTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoSteelbody
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "declares Mental Strength's verified costs, cast time, and duration" do
    assert {:ok, definition} = Catalog.by_id(268)
    assert definition.name == :mo_steelbody
    assert definition.status == :sc_steelbody
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.max_level == 5
    assert definition.sp_cost == List.duplicate(200, 5)
    assert definition.sphere_cost == List.duplicate(5, 5)
    assert definition.cast_time == List.duplicate(2_500, 5)
    assert definition.fixed_cast_time == List.duplicate(2_500, 5)
    assert definition.duration == [30_000, 60_000, 90_000, 120_000, 150_000]
  end

  test "applies Mental Strength with its level-specific duration" do
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_steelbody, params ->
      assert params == [val1: 4, caster_id: 1000, duration: 120_000]
      :ok
    end)

    assert {:ok, ^caster} = MoSteelbody.cast(caster, :self, 4, MoSteelbody.definition())
  end

  test "propagates Mental Strength application failures" do
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_steelbody, _params ->
      {:error, :conflict}
    end)

    assert {:error, :conflict} = MoSteelbody.cast(caster, :self, 1, MoSteelbody.definition())
  end
end
