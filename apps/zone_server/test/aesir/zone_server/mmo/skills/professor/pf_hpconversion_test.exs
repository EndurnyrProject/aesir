defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfHpconversionTest do
  use ExUnit.Case, async: true

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
  defp vitals(%PlayerState{stats: %{current_state: %{hp: hp, sp: sp}}}), do: {hp, sp}

  test "pays a tenth of max HP to regain that per level in SP, clamped at max SP" do
    assert {:ok, converted} = PfHpconversion.cast(caster(500, 7), :self, 3, definition())
    assert vitals(converted) == {400, 7 + 300}

    assert {:ok, clamped} = PfHpconversion.cast(caster(500, 450), :self, 3, definition())
    assert vitals(clamped) == {400, 500}
  end

  test "with HP not above the charge nothing happens" do
    assert {:ok, failed} = PfHpconversion.cast(caster(100, 7), :self, 3, definition())
    assert vitals(failed) == {100, 7}
  end

  test "is unusable at full SP" do
    assert PfHpconversion.validate(caster(500, 500), :self, 1, definition()) == {:error, :sp_full}
    assert PfHpconversion.validate(caster(500, 499), :self, 1, definition()) == :ok
  end
end
