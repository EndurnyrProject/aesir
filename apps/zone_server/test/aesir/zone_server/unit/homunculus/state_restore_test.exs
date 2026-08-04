defmodule Aesir.ZoneServer.Unit.Homunculus.StateRestoreTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Unit.Homunculus.StateRestore

  test "rejects an unknown learned skill" do
    assert {:error, :invalid_skills} =
             restore(learned_skills: %{"8999" => 1})
  end

  test "rejects a learned rank above the class maximum" do
    assert {:error, :invalid_skills} =
             restore(learned_skills: %{"8001" => 6})
  end

  test "rejects a cooldown outside the current class tree" do
    assert {:error, :invalid_skills} =
             restore(cooldowns: %{"8999" => 100})
  end

  test "rejects malformed and duplicate-normalized maps" do
    assert {:error, :invalid_map} = restore(learned_skills: nil)

    assert {:error, :invalid_map} =
             restore(learned_skills: %{8_001 => 1, "8001" => 1})
  end

  test "restores a valid evolved class tree" do
    assert {:ok, state} =
             restore(class_id: 6_009, learned_skills: %{"8001" => 5, "8004" => 3})

    assert state.class_id == 6_009
    assert state.learned_skills == %{8_001 => 5, 8_004 => 3}
    assert Map.keys(state.ai_config.skills) |> Enum.sort() == [8_001, 8_004]
  end

  test "encoded active and passive manual rows survive relog restoration" do
    specs = [
      %{id: 8_001, target: :owner, allowed_thresholds: [:self_hp, :owner_hp]},
      %{id: 8_003, target: :self, allowed_thresholds: []}
    ]

    encoded = specs |> Config.default() |> Config.encode()

    assert {:ok, state} =
             restore(learned_skills: %{"8001" => 1, "8003" => 1}, ai_config: encoded)

    assert state.ai_config == Config.default(specs)
    assert Map.keys(state.ai_config.skills) |> Enum.sort() == [8_001, 8_003]
  end

  test "empty maps restore the intended legacy AI default" do
    assert {:ok, state} = restore(learned_skills: %{}, cooldowns: %{}, ai_config: %{})
    assert state.ai_config == Config.default([])
  end

  defp restore(overrides) do
    row =
      struct!(Homunculus, %{
        id: 1,
        character_id: 2,
        class_id: 6_001,
        name: "Hildr",
        rename_available: true,
        lifecycle: "active",
        level: 50,
        exp: 0,
        skill_points: 0,
        hp: 800,
        max_hp: 1_000,
        sp: 100,
        max_sp: 200,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        hunger: 32,
        intimacy_hundredths: 2_100,
        active_remaining_ms: 1_800_000,
        learned_skills: %{"8001" => 1},
        cooldowns: %{},
        ai_config: %{}
      })

    StateRestore.restore(struct!(row, overrides))
  end
end
