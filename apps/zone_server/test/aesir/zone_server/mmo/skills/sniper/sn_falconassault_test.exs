defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.SnFalconassaultTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skills.Sniper.SnFalconassault
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "requires the falcon option bit" do
    caster = %PlayerState{character_id: 1001, option: 0}
    definition = SnFalconassault.definition()

    assert {:error, :falcon_not_equipped} =
             SnFalconassault.begin_attempt(caster, {:unit, 2001}, 5, definition)

    falconer = %{caster | option: Option.id(:falcon)}

    assert {:ok, ^falconer} =
             SnFalconassault.begin_attempt(falconer, {:unit, 2001}, 5, definition)
  end
end
