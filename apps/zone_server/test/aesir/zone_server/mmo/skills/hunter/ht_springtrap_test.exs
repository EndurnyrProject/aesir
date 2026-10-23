defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSpringtrapTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSpringtrap
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Mimic.copy(Manager)
    :ok
  end

  defp caster(option \\ 0) do
    %PlayerState{
      character_id: 1000,
      map_name: "prontera",
      x: 50,
      y: 50,
      option: option,
      inventory: %{}
    }
  end

  test "requires an equipped Falcon before effects" do
    definition = HtSpringtrap.definition()

    assert {:error, :falcon_required} =
             HtSpringtrap.begin_attempt(caster(), {:ground, 51, 50}, 1, definition)

    assert {:ok, _caster} =
             HtSpringtrap.begin_attempt(
               caster(Option.id(:falcon)),
               {:ground, 51, 50},
               1,
               definition
             )
  end

  test "springs the targeted eligible trap without changing inventory" do
    definition = HtSpringtrap.definition()
    caster = caster(Option.id(:falcon))

    expect(Manager, :spring_trap, fn "prontera", 51, 50 ->
      {:ok, %{group_id: 44, expires_at: 11_500}}
    end)

    assert {:ok, updated} = HtSpringtrap.cast(caster, {:ground, 51, 50}, 3, definition)
    assert updated == caster
  end

  test "an ineligible spring is a silent no-op" do
    definition = HtSpringtrap.definition()
    caster = caster(Option.id(:falcon))
    errors = %{51 => :not_found, 52 => :already_spent, 53 => :unsupported_trap}

    stub(Manager, :spring_trap, fn "prontera", x, 50 ->
      {:error, Map.fetch!(errors, x)}
    end)

    Enum.each(errors, fn {x, _reason} ->
      assert {:ok, ^caster} = HtSpringtrap.cast(caster, {:ground, x, 50}, 1, definition)
    end)
  end
end
