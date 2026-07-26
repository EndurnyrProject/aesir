defmodule Aesir.ZoneServer.Mmo.Skill.GrantTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Grant

  setup :verify_on_exit!

  defp quest_definition(overrides \\ []) do
    struct!(
      %Definition{
        id: 9001,
        name: :test_quest_skill,
        display_name: "Test Quest Skill",
        max_level: 5,
        quest_skill: true,
        quest_owner_job: :archer
      },
      overrides
    )
  end

  describe "grant/3" do
    test "returns :unknown_skill for an unresolvable skill id" do
      stub(Catalog, :by_id, fn 9999 -> :error end)

      assert Grant.grant(%{}, 9999, 1) == {:error, :unknown_skill}
    end

    test "returns :unknown_skill for an unresolvable skill name" do
      stub(Catalog, :by_name, fn :bogus_skill -> :error end)

      assert Grant.grant(%{}, :bogus_skill, 1) == {:error, :unknown_skill}
    end

    test "returns :invalid_level below 1" do
      stub(Catalog, :by_id, fn 9001 -> {:ok, quest_definition()} end)

      assert Grant.grant(%{}, 9001, 0) == {:error, :invalid_level}
    end

    test "returns :invalid_level above max_level" do
      stub(Catalog, :by_id, fn 9001 -> {:ok, quest_definition()} end)

      assert Grant.grant(%{}, 9001, 6) == {:error, :invalid_level}
    end

    test "returns :not_grantable for a non-quest skill" do
      stub(Catalog, :by_id, fn 9001 ->
        {:ok, quest_definition(quest_skill: false, quest_owner_job: nil)}
      end)

      assert Grant.grant(%{}, 9001, 1) == {:error, :not_grantable}
    end

    test "returns :not_grantable for a quest skill defensively missing an owner job" do
      stub(Catalog, :by_id, fn 9001 ->
        {:ok, quest_definition(quest_owner_job: nil)}
      end)

      assert Grant.grant(%{}, 9001, 1) == {:error, :not_grantable}
    end

    test "grants a new skill at the requested level by id" do
      stub(Catalog, :by_id, fn 9001 -> {:ok, quest_definition()} end)

      assert Grant.grant(%{}, 9001, 3) == {:ok, %{9001 => 3}}
    end

    test "grants a new skill at the requested level by name" do
      stub(Catalog, :by_name, fn :test_quest_skill -> {:ok, quest_definition()} end)

      assert Grant.grant(%{}, :test_quest_skill, 3) == {:ok, %{9001 => 3}}
    end

    test "keeps the greater level on a repeated lower-level grant" do
      stub(Catalog, :by_id, fn 9001 -> {:ok, quest_definition()} end)

      assert Grant.grant(%{9001 => 3}, 9001, 1) == {:ok, %{9001 => 3}}
    end

    test "keeps the requested level on an equal repeated grant" do
      stub(Catalog, :by_id, fn 9001 -> {:ok, quest_definition()} end)

      assert Grant.grant(%{9001 => 3}, 9001, 3) == {:ok, %{9001 => 3}}
    end

    test "raises the level on a higher repeated grant" do
      stub(Catalog, :by_id, fn 9001 -> {:ok, quest_definition()} end)

      assert Grant.grant(%{9001 => 1}, 9001, 5) == {:ok, %{9001 => 5}}
    end

    test "preserves unrelated learned skills" do
      stub(Catalog, :by_id, fn 9001 -> {:ok, quest_definition()} end)

      assert Grant.grant(%{1 => 10, 2 => 5}, 9001, 3) == {:ok, %{1 => 10, 2 => 5, 9001 => 3}}
    end

    test "does not mutate the learned map on failure" do
      stub(Catalog, :by_id, fn 9001 -> {:ok, quest_definition()} end)

      learned = %{1 => 10, 9001 => 2}
      assert Grant.grant(learned, 9001, 0) == {:error, :invalid_level}
    end
  end
end
