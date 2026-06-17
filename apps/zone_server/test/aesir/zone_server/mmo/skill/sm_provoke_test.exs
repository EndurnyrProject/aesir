defmodule Aesir.ZoneServer.Mmo.Skill.SmProvokeTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Behaviors
  alias Aesir.ZoneServer.Mmo.Skill.Behaviors.SmProvoke
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Behaviors.module_for/1 resolves sm_provoke" do
    assert {:ok, SmProvoke} = Behaviors.module_for(:sm_provoke)
  end

  test "cast/4 applies SC_PROVOKE to mob with val2=2+3*level, val3=5+5*level" do
    {:ok, definition} = Catalog.by_id(6)
    caster = %{character_id: 1}
    mob_id = 500
    level = 3
    duration = Enum.at(definition.duration, level - 1)

    expect(StatusInterpreter, :apply_status, fn :mob,
                                                ^mob_id,
                                                :sc_provoke,
                                                [
                                                  val1: ^level,
                                                  val2: 11,
                                                  val3: 20,
                                                  caster_id: 1,
                                                  duration: ^duration
                                                ] ->
      :ok
    end)

    assert {:ok, ^caster} = SmProvoke.cast(caster, {:unit, mob_id}, level, definition)
  end
end
