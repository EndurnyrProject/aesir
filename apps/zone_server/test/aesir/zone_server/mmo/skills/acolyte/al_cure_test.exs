defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlCureTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlCure
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "cast/4 removes rAthena's four curable statuses from a targeted ally" do
    {:ok, definition} = Catalog.by_id(35)
    caster = %{character_id: 1000}
    target_id = 2000

    expect(StatusInterpreter, :remove_status, fn :player, ^target_id, :sc_silence -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, ^target_id, :sc_blind -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, ^target_id, :sc_confusion -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, ^target_id, :sc_bitescar -> :ok end)

    assert {:ok, ^caster} = AlCure.cast(caster, {:unit, target_id}, 1, definition)
  end

  test "cast/4 removes all three statuses on :self" do
    {:ok, definition} = Catalog.by_id(35)
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :remove_status, fn :player, 1000, :sc_silence -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, 1000, :sc_blind -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, 1000, :sc_confusion -> :ok end)
    expect(StatusInterpreter, :remove_status, fn :player, 1000, :sc_bitescar -> :ok end)

    assert {:ok, ^caster} = AlCure.cast(caster, :self, 1, definition)
  end

  test "cast/4 still returns {:ok, caster} when statuses are absent (remove_status is a no-op)" do
    {:ok, definition} = Catalog.by_id(35)
    caster = %{character_id: 1000}
    target_id = 3000

    stub(StatusInterpreter, :remove_status, fn :player, ^target_id, _status -> :ok end)

    assert {:ok, ^caster} = AlCure.cast(caster, {:unit, target_id}, 1, definition)
  end
end
