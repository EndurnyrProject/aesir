defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GunShotsTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsRapidshower
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsTracking
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsTripleaction

  setup :set_mimic_private

  test "shots deliver the reference damage ratio and signed hit divisions" do
    caster = %{character_id: 1}

    for {skill, level, ratio, divisions} <- [
          {GsTripleaction, 1, 150, 3},
          {GsTracking, 5, 700, 1},
          {GsRapidshower, 5, 750, -5}
        ] do
      expect(Combat, :execute_skill_attack, fn ^caster, 2, opts ->
        assert opts[:skill_ratio] == ratio
        assert opts[:hit_divisions] == divisions
        :ok
      end)

      assert {:ok, ^caster} = skill.cast(caster, {:unit, 2}, level, skill.definition())
    end
  end
end
