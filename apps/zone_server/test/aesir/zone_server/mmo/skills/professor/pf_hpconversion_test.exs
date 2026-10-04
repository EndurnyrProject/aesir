defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfHpconversionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfHpconversion
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defp caster(hp, sp, max_sp \\ 500) do
    %PlayerState{
      character_id: 1,
      stats: %{
        current_state: %{hp: hp, sp: sp},
        derived_stats: %{max_hp: 1_000, max_sp: max_sp}
      }
    }
  end

  defp definition, do: PfHpconversion.definition()

  test "costs a tenth of max HP and refuses when HP is not above it" do
    cost = PfHpconversion.dynamic_cost(caster(500, 10), :self, 3, definition())

    assert {cost.hp, cost.sp, cost.sp_requirement} == {100, 0, 3}
    assert Cost.validate(caster(101, 10), cost) == :ok
    assert Cost.validate(caster(100, 10), cost) == {:error, :insufficient_hp}
  end

  test "converts a tenth of max HP per level into SP, clamped at max SP" do
    assert {:ok, converted} = PfHpconversion.cast(caster(500, 10), :self, 3, definition())
    assert converted.stats.current_state.sp == 10 - 3 + 300

    assert {:ok, clamped} = PfHpconversion.cast(caster(500, 450), :self, 3, definition())
    assert clamped.stats.current_state.sp == 500
  end

  test "is unusable at full SP" do
    assert PfHpconversion.validate(caster(500, 500), :self, 1, definition()) == {:error, :sp_full}
    assert PfHpconversion.validate(caster(500, 499), :self, 1, definition()) == :ok
  end
end
