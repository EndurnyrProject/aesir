defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AcolyteModeDefinitionsTest do
  @moduledoc """
  Locks every Acolyte definition field that differs between the two rulesets.

  `definition/1` is pure, so both modes are asserted from one untagged test
  regardless of the booted mode.
  """
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlAngelus
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlCrucis
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDecagi
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolylight
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolywater
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlIncagi
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AllResurrection
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlWarp

  describe "cast timings that split by mode" do
    test "Increase AGI trades a fixed cast for a longer variable one" do
      assert AlIncagi.definition(:renewal).cast_time == List.duplicate(800, 10)
      assert AlIncagi.definition(:pre_renewal).cast_time == List.duplicate(1_000, 10)
      assert AlIncagi.definition(:renewal).fixed_cast_time == List.duplicate(200, 10)
      assert AlIncagi.definition(:pre_renewal).fixed_cast_time == []
      assert AlIncagi.definition(:renewal).after_cast_delay == List.duplicate(400, 10)
      assert AlIncagi.definition(:pre_renewal).after_cast_delay == List.duplicate(1_000, 10)
    end

    test "Increase AGI costs the same HP in both modes" do
      assert AlIncagi.definition(:renewal).hp_cost == List.duplicate(15, 10)
      assert AlIncagi.definition(:pre_renewal).hp_cost == List.duplicate(15, 10)
    end

    test "Decrease AGI keeps its after-cast delay but not its fixed cast" do
      assert AlDecagi.definition(:renewal).cast_time == List.duplicate(750, 10)
      assert AlDecagi.definition(:pre_renewal).cast_time == List.duplicate(1_000, 10)
      assert AlDecagi.definition(:pre_renewal).fixed_cast_time == []

      assert AlDecagi.definition(:renewal).after_cast_delay ==
               AlDecagi.definition(:pre_renewal).after_cast_delay
    end

    test "Signum Crucis casts slower and unsplit in pre-renewal" do
      assert AlCrucis.definition(:renewal).cast_time == List.duplicate(350, 10)
      assert AlCrucis.definition(:pre_renewal).cast_time == List.duplicate(500, 10)
      assert AlCrucis.definition(:pre_renewal).fixed_cast_time == []
    end

    test "Heal is locked out for twice as long in pre-renewal" do
      assert AlHeal.definition(:renewal).after_cast_delay == List.duplicate(500, 10)
      assert AlHeal.definition(:pre_renewal).after_cast_delay == List.duplicate(1_000, 10)
    end

    test "Aqua Benedicta and Holy Light cast slower in pre-renewal" do
      assert AlHolywater.definition(:renewal).cast_time == [800]
      assert AlHolywater.definition(:pre_renewal).cast_time == [1_000]
      assert AlHolylight.definition(:renewal).cast_time == [800]
      assert AlHolylight.definition(:pre_renewal).cast_time == [2_000]
    end

    test "Resurrection's ladder is slower and unsplit in pre-renewal" do
      assert AllResurrection.definition(:renewal).cast_time == [4_800, 3_200, 1_600, 0]
      assert AllResurrection.definition(:pre_renewal).cast_time == [6_000, 4_000, 2_000, 0]
      assert AllResurrection.definition(:pre_renewal).fixed_cast_time == []
    end
  end

  describe "fields that split by mode beyond cast timing" do
    test "Angelus loses its cooldown and reaches the whole visible area in pre-renewal" do
      assert AlAngelus.definition(:renewal).cooldown == List.duplicate(30_000, 10)
      assert AlAngelus.definition(:pre_renewal).cooldown == []
      assert AlAngelus.definition(:renewal).splash_radius == 18
      assert AlAngelus.definition(:pre_renewal).splash_radius == 14
      assert AlAngelus.definition(:renewal).after_cast_delay == List.duplicate(500, 10)
      assert AlAngelus.definition(:pre_renewal).after_cast_delay == List.duplicate(3_500, 10)
    end

    test "Warp Portal opens for a shorter time and chains freely in pre-renewal" do
      assert AlWarp.definition(:renewal).unit_duration == [10_000, 15_000, 20_000, 25_000]
      assert AlWarp.definition(:pre_renewal).unit_duration == [5_000, 10_000, 15_000, 20_000]
      assert AlWarp.definition(:renewal).cast_time == []
      assert AlWarp.definition(:pre_renewal).cast_time == List.duplicate(1_000, 4)
      assert AlWarp.definition(:renewal).after_cast_delay == List.duplicate(1_000, 4)
      assert AlWarp.definition(:pre_renewal).after_cast_delay == []
    end
  end
end
