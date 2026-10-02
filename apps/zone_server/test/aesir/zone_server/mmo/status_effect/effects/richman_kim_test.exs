defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RichmanKimTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.RichmanKim
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :verify_on_exit!
  setup :set_mimic_private

  test "renewal raises the holder's EXP rate by 10 + 10 * level percent" do
    stub(GameMode, :mode, fn -> :renewal end)

    assert %{exp_rate: 20} == RichmanKim.modifiers(entry(1), %{})
    assert %{exp_rate: 60} == RichmanKim.modifiers(entry(5), %{})
  end

  test "pre-renewal grants the holder no EXP rate because the bonus rides on the killed mob" do
    stub(GameMode, :mode, fn -> :pre_renewal end)

    assert %{} == RichmanKim.modifiers(entry(5), %{})
  end

  test "pre-renewal kill bonus is 25 + 11 * level percent" do
    assert RichmanKim.kill_exp_bonus(1) == 36
    assert RichmanKim.kill_exp_bonus(5) == 80
  end

  defp entry(level), do: %StatusEntry{type: :sc_richmankim, val1: level}
end
