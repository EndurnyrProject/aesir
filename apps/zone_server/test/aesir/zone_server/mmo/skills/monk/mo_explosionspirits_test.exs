defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoExplosionspiritsTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoExplosionspirits
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "applies Fury with its level and 180-second duration" do
    caster = %{character_id: 1000}
    definition = MoExplosionspirits.definition()

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_explosionspirits, params ->
      assert params == [val1: 3, caster_id: 1000, duration: 180_000]
      :ok
    end)

    assert {:ok, ^caster} = MoExplosionspirits.cast(caster, :self, 3, definition)
  end

  test "keeps the cast when Fury is refused" do
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_explosionspirits, _params ->
      {:error, :conflict}
    end)

    assert {:ok, ^caster} =
             MoExplosionspirits.cast(caster, :self, 1, MoExplosionspirits.definition())
  end
end
