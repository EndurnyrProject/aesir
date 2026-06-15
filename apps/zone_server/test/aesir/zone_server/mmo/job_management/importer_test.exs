defmodule Aesir.ZoneServer.Mmo.JobManagement.ImporterTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.Importer

  # Novice is fully table-driven; Dragon_Knight and Night_Watch ship no HP/SP
  # table (only BaseAp), so they exercise the formula fallback. HpIncrease/
  # SpIncrease of 100 with no factor make calc_basehp/sp = 35+level / 10+level.
  defp bodies do
    %{
      stats: [
        %{"Jobs" => %{"Novice" => true}, "BonusStats" => [%{"Level" => 2, "Luk" => 1}]},
        %{
          "Jobs" => %{"Dragon_Knight" => true},
          "MaxWeight" => 45_000,
          "HpIncrease" => 100,
          "SpIncrease" => 100
        },
        %{"Jobs" => %{"Night_Watch" => true}, "HpIncrease" => 100, "SpIncrease" => 100}
      ],
      basepoints: [
        # BaseHp and BaseSp live in separate groups - merge must keep both.
        %{"Jobs" => %{"Novice" => true}, "BaseHp" => [hp(1, 40), hp(2, 45)]},
        %{"Jobs" => %{"Novice" => true}, "BaseSp" => [sp(1, 10), sp(2, 11)]},
        %{"Jobs" => %{"Dragon_Knight" => true, "Night_Watch" => true}, "BaseAp" => [ap(200, 200)]}
      ],
      aspd: [
        %{"Jobs" => %{"Novice" => true}, "BaseASPD" => %{"Fist" => 40, "1hSword" => 57}},
        %{
          "Jobs" => %{"Dragon_Knight" => true, "Night_Watch" => true},
          "BaseASPD" => %{"2hSword" => 80}
        }
      ],
      exp: [
        %{"Jobs" => %{"Novice" => true}, "MaxBaseLevel" => 2, "BaseExp" => [exp(1, 548)]},
        %{"Jobs" => %{"Dragon_Knight" => true}, "MaxBaseLevel" => 3, "BaseExp" => [exp(1, 9)]},
        %{"Jobs" => %{"Night_Watch" => true}, "MaxBaseLevel" => 5, "BaseExp" => [exp(1, 9)]},
        %{"Jobs" => %{"Novice" => true}, "MaxJobLevel" => 2, "JobExp" => [exp(1, 10)]},
        %{
          "Jobs" => %{"Dragon_Knight" => true, "Night_Watch" => true},
          "MaxJobLevel" => 5,
          "JobExp" => [exp(1, 100)]
        }
      ]
    }
  end

  defp hp(level, v), do: %{"Level" => level, "Hp" => v}
  defp sp(level, v), do: %{"Level" => level, "Sp" => v}
  defp ap(level, v), do: %{"Level" => level, "Ap" => v}
  defp exp(level, v), do: %{"Level" => level, "Exp" => v}

  defp by_id, do: Map.new(Importer.build(bodies()), &{&1["id"], &1})

  describe "build/1" do
    test "merges BaseHp and BaseSp from separate basepoints groups" do
      assert %{
               "id" => 0,
               "name" => "novice",
               "max_weight" => 20_000,
               "max_base_level" => 2,
               "max_job_level" => 2,
               "base_hp" => [40, 45],
               "base_sp" => [10, 11],
               "base_exp" => [548],
               "job_exp" => [10],
               "bonus_stats" => [%{"level" => 2, "luk" => 1}],
               "base_aspd" => %{"fist" => 40, "one_handed_sword" => 57}
             } = by_id()[0]
    end

    test "fills HP/SP from the formula for a tableless job and prunes all-zero AP" do
      dk = by_id()[4252]

      # calc_basehp = 35 + level, calc_basesp = 10 + level (HpIncrease/SpIncrease 100, no factor)
      assert %{"base_hp" => [36, 37, 38], "base_sp" => [11, 12, 13], "max_base_level" => 3} = dk
      # BaseAp only defines level 200 (> max_base_level 3) so AP is all-zero and dropped.
      refute Map.has_key?(dk, "base_ap")
    end

    test "applies the gunslinger SP branch to formula-driven Night_Watch" do
      # Gunslinger calc_basesp below level 10 is 9 + 3*level, ignoring factors.
      assert %{"base_sp" => [12, 15, 18, 21, 24]} = by_id()[4306]
    end

    test "raises on a job name not present in AvailableJobs" do
      assert_raise RuntimeError, ~r/no job id for :bogus_job/, fn ->
        Importer.build(solo_bodies("Bogus_Job", %{"Fist" => 40}))
      end
    end

    test "raises on an unknown weapon type" do
      assert_raise RuntimeError, ~r/unknown weapon type "Spork"/, fn ->
        Importer.build(solo_bodies("Novice", %{"Spork" => 1}))
      end
    end
  end

  # A complete single-job body set, so build/1 reaches id resolution and aspd mapping.
  defp solo_bodies(rname, aspd) do
    %{
      stats: [],
      basepoints: [%{"Jobs" => %{rname => true}, "BaseHp" => [hp(1, 40)]}],
      aspd: [%{"Jobs" => %{rname => true}, "BaseASPD" => aspd}],
      exp: [
        %{"Jobs" => %{rname => true}, "MaxBaseLevel" => 1, "BaseExp" => [exp(1, 1)]},
        %{"Jobs" => %{rname => true}, "MaxJobLevel" => 1, "JobExp" => [exp(1, 1)]}
      ]
    }
  end

  describe "tier/1" do
    test "classifies jobs by id and baby name" do
      assert "basic" = Importer.tier(%{"id" => 0, "name" => "novice"})
      assert "2nd" = Importer.tier(%{"id" => 7, "name" => "knight"})
      assert "trans" = Importer.tier(%{"id" => 4008, "name" => "lord_knight"})
      assert "3rd" = Importer.tier(%{"id" => 4054, "name" => "rune_knight"})
      assert "4th" = Importer.tier(%{"id" => 4252, "name" => "dragon_knight"})
      assert "baby" = Importer.tier(%{"id" => 4024, "name" => "baby_swordman"})
      assert "special" = Importer.tier(%{"id" => 4046, "name" => "taekwon"})
    end
  end
end
