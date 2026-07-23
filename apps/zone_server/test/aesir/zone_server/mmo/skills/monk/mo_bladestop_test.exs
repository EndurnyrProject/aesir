defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBladestopTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoBladestop
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "declares Root's verified costs, durations, and level data" do
    assert {:ok, definition} = Catalog.by_id(269)
    assert definition.name == :mo_bladestop
    assert definition.status == :sc_bladestop_wait
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.max_level == 5
    assert definition.sp_cost == List.duplicate(10, 5)
    assert definition.sphere_cost == List.duplicate(1, 5)
    assert definition.after_cast_delay == List.duplicate(500, 5)
    assert definition.cooldown == List.duplicate(3_000, 5)
    assert definition.duration == [500, 700, 900, 1_100, 1_300]
    assert definition.cast_time == []
  end

  test "arms the waiting stance with the level-specific duration and Root level" do
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_bladestop_wait, params ->
      assert params == [val1: 3, caster_id: 1000, duration: 900]
      :ok
    end)

    assert {:ok, ^caster} = MoBladestop.cast(caster, :self, 3, MoBladestop.definition())
  end

  test "propagates a waiting-stance application failure" do
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_bladestop_wait, _params ->
      {:error, :conflict}
    end)

    assert {:error, :conflict} = MoBladestop.cast(caster, :self, 1, MoBladestop.definition())
  end
end
