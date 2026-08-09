defmodule Aesir.ZoneServer.Mmo.Combat.HallucinationTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat.Hallucination
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :setup_ets_tables

  defp dealt(damage, damage2 \\ 0, target_id \\ 100) do
    %DamageDealt{
      src_id: 1,
      target_id: target_id,
      server_tick: 0,
      src_speed: 500,
      dmg_speed: 500,
      damage: damage,
      div: 1,
      type: 0,
      damage2: damage2,
      is_sp_damage: false
    }
  end

  defp skill(damage, target_id \\ 100) do
    %SkillDamage{
      skill_id: 5,
      level: 1,
      src_id: 1,
      target_id: target_id,
      server_tick: 0,
      src_delay: 0,
      dst_delay: 0,
      damage: damage,
      div: 1,
      type: 6
    }
  end

  describe "maybe_garble/2 without the status" do
    test "leaves the damage untouched for a healthy target" do
      packet = dealt(1234, 56)
      assert Hallucination.maybe_garble(packet, :player) == packet
    end

    test "passes through when the unit type is nil" do
      packet = dealt(1234)
      assert Hallucination.maybe_garble(packet, nil) == packet
    end

    test "ignores packets that carry no damage number" do
      other = %{some: :packet}
      assert Hallucination.maybe_garble(other, :player) == other
    end
  end

  describe "maybe_garble/2 with SC_HALLUCINATION" do
    setup do
      StatusStorage.apply_status(:player, 100, :sc_hallucination)
      :ok
    end

    test "randomizes a positive DamageDealt number for the afflicted target" do
      results =
        for _ <- 1..200 do
          Hallucination.maybe_garble(dealt(9999), :player).damage
        end

      assert Enum.all?(results, &(&1 >= 0 and &1 < 32_767))
      # The true value must not be the only thing ever shown.
      refute Enum.all?(results, &(&1 == 9999))
    end

    test "randomizes damage2 as well" do
      results =
        for _ <- 1..200 do
          Hallucination.maybe_garble(dealt(9999, 8888), :player).damage2
        end

      assert Enum.all?(results, &(&1 >= 0 and &1 < 32_767))
      refute Enum.all?(results, &(&1 == 8888))
    end

    test "never garbles a zero (miss / guard / dodge)" do
      for _ <- 1..50 do
        assert Hallucination.maybe_garble(dealt(0, 0), :player) == dealt(0, 0)
      end
    end

    test "randomizes SkillDamage numbers" do
      results =
        for _ <- 1..200 do
          Hallucination.maybe_garble(skill(12_345), :player).damage
        end

      assert Enum.all?(results, &(&1 >= 0 and &1 < 32_767))
      refute Enum.all?(results, &(&1 == 12_345))
    end

    test "only affects the afflicted unit, not a different id" do
      packet = dealt(4321, 0, 999)
      assert Hallucination.maybe_garble(packet, :player) == packet
    end

    test "keys on unit type: a mob sharing the id is unaffected" do
      packet = dealt(4321, 0, 100)
      assert Hallucination.maybe_garble(packet, :mob) == packet
    end
  end
end
