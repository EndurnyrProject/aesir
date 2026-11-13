defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsPassivesTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSingleaction
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSnakeeye

  test "gun passives grant hit, range and mode-specific attack speed" do
    for weapon <- [:revolver, :rifle, :gatling, :shotgun, :grenade] do
      ctx = %{weapon_type: weapon}
      assert GsSingleaction.hit_bonus(10, ctx) == 20
      assert GsSnakeeye.hit_bonus(10, ctx) == 10
      assert GsSnakeeye.range_bonus(10, ctx) == 10
      assert GsSingleaction.aspd_bonus(10, ctx) == if(GameMode.mode() == :renewal, do: 5, else: 0)

      assert GsSingleaction.aspd_rate_bonus(10, ctx) ==
               if(GameMode.mode() == :pre_renewal, do: 5, else: 0)

      assert GsSingleaction.aspd_bonus(3, ctx) == if(GameMode.mode() == :renewal, do: 2, else: 0)

      assert GsSingleaction.aspd_rate_bonus(3, ctx) ==
               if(GameMode.mode() == :pre_renewal, do: 2, else: 0)
    end
  end

  test "non-guns receive no bonuses" do
    for weapon <- [:bow, :fist, :dagger] do
      ctx = %{weapon_type: weapon}
      assert GsSingleaction.hit_bonus(10, ctx) == 0
      assert GsSingleaction.aspd_bonus(10, ctx) == 0
      assert GsSingleaction.aspd_rate_bonus(10, ctx) == 0
      assert GsSnakeeye.hit_bonus(10, ctx) == 0
      assert GsSnakeeye.range_bonus(10, ctx) == 0
    end
  end
end
