defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmFatalblowTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmFatalblow

  @ctx %{base_level: 50}

  test "skill_name/0" do
    assert SmFatalblow.skill_name() == :sm_fatalblow
  end

  @tag game_mode: :renewal
  test "renewal stuns for four and a half seconds when bash level > 5" do
    assert {:apply_status, :sc_stun, opts} = SmFatalblow.skill_rider(:sm_bash, 6, 1, @ctx)
    assert Keyword.get(opts, :chance) == (6 - 5) * 50 * 10
    assert Keyword.get(opts, :duration) == 4_500
  end

  @tag game_mode: :pre_renewal
  test "classic stuns for a full five seconds when bash level > 5" do
    assert {:apply_status, :sc_stun, opts} = SmFatalblow.skill_rider(:sm_bash, 6, 1, @ctx)
    assert Keyword.get(opts, :chance) == (6 - 5) * 50 * 10
    assert Keyword.get(opts, :duration) == 5_000
  end

  test "returns :none when bash level <= 5" do
    assert SmFatalblow.skill_rider(:sm_bash, 5, 1, @ctx) == :none
  end

  test "returns :none for other skills" do
    assert SmFatalblow.skill_rider(:sm_magnum, 10, 1, @ctx) == :none
  end
end
