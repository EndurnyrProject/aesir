defmodule Aesir.ZoneServer.Mmo.Skill.Passives.SmFatalblowTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Passives.SmFatalblow

  @ctx %{base_level: 50}

  test "skill_name/0" do
    assert SmFatalblow.skill_name() == :sm_fatalblow
  end

  test "returns a stun rider when bash level > 5" do
    assert {:apply_status, :sc_stun, opts} = SmFatalblow.skill_rider(:sm_bash, 6, 1, @ctx)
    assert Keyword.get(opts, :chance) == (6 - 5) * 50 * 10
    assert Keyword.get(opts, :duration) == 4_500
  end

  test "returns :none when bash level <= 5" do
    assert SmFatalblow.skill_rider(:sm_bash, 5, 1, @ctx) == :none
  end

  test "returns :none for other skills" do
    assert SmFatalblow.skill_rider(:sm_magnum, 10, 1, @ctx) == :none
  end
end
