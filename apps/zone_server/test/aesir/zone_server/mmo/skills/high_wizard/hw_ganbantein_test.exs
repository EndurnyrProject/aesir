defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwGanbanteinTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skills.HighWizard.HwGanbantein
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  setup do
    Mimic.copy(Manager)
    :ok
  end

  @caster %PlayerState{character_id: 1, map_name: "prontera"}

  defp cast(roll),
    do:
      HwGanbantein.cast(@caster, {:ground, 100, 100}, 1, HwGanbantein.definition(),
        rng: fn 100 -> roll end
      )

  test "an 80% success clears every ground unit cell in the 3x3 around the target" do
    expect(Manager, :clear_area, fn "prontera", cells ->
      assert Enum.sort(cells) == for(x <- 99..101, y <- 99..101, do: {x, y})
      :ok
    end)

    assert {:ok, @caster} = cast(80)
  end

  test "a failed roll clears nothing and spares the gemstones" do
    reject(&Manager.clear_area/2)

    assert {:ok, @caster, :no_consume} = cast(81)
  end
end
