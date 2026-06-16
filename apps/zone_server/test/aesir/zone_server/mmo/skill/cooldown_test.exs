defmodule Aesir.ZoneServer.Mmo.Skill.CooldownTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  defp definition(cooldown) do
    %Definition{
      id: 29,
      name: :test_skill,
      display_name: "Test Skill",
      max_level: 10,
      cooldown: cooldown
    }
  end

  describe "ready?/3" do
    test "true when no entry exists" do
      assert Cooldown.ready?(%{}, 29, 1_000)
    end

    test "false while the cooldown is active" do
      refute Cooldown.ready?(%{29 => 2_000}, 29, 1_000)
    end

    test "true at the expiry boundary (now == expires_at)" do
      assert Cooldown.ready?(%{29 => 1_000}, 29, 1_000)
    end

    test "true after the cooldown has expired" do
      assert Cooldown.ready?(%{29 => 1_000}, 29, 1_500)
    end
  end

  describe "put/3" do
    test "records expires_at for the skill" do
      assert %{29 => 5_000} = Cooldown.put(%{}, 29, 5_000)
    end

    test "overwrites an existing entry" do
      assert %{29 => 9_000} = Cooldown.put(%{29 => 1_000}, 29, 9_000)
    end
  end

  describe "duration/2" do
    test "returns the per-level value" do
      definition = definition([1_000, 2_000, 3_000])

      assert Cooldown.duration(definition, 1) == 1_000
      assert Cooldown.duration(definition, 3) == 3_000
    end

    test "returns 0 for an empty cooldown list" do
      assert Cooldown.duration(definition([]), 1) == 0
    end

    test "returns 0 when the level is past the end of the list" do
      assert Cooldown.duration(definition([1_000, 2_000]), 5) == 0
    end
  end
end
