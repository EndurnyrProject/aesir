defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlTeleportTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlTeleport
  alias Aesir.ZoneServer.Mmo.SkillTree

  setup do
    Mimic.copy(Cell)
    :ok
  end

  setup :verify_on_exit!

  @caster %{
    character_id: 1001,
    map_name: "morocc",
    x: 155,
    y: 100,
    save_map: "prontera",
    save_x: 150,
    save_y: 190,
    pending_warp: nil
  }

  describe "Catalog" do
    test "by_id/1 resolves al_teleport with correct definition" do
      assert {:ok, defn} = Catalog.by_id(26)
      assert defn.name == :al_teleport
      assert defn.display_name == "Teleport"
      assert defn.max_level == 2
      assert defn.target_type == :self
      assert defn.sp_cost == [10, 9]
    end

    test "by_name/1 resolves :al_teleport" do
      assert {:ok, %{id: 26}} = Catalog.by_name(:al_teleport)
    end
  end

  describe "Acolyte skill tree" do
    test "AL_TELEPORT appears in the Acolyte tree" do
      {:ok, acolyte_id} = AvailableJobs.job_name_to_id(:acolyte)
      tree = SkillTree.tree_for(acolyte_id)
      assert Map.has_key?(tree, 26)
    end
  end

  describe "cast/4 (lv1 — random cell on current map)" do
    test "stages pending_warp to a random walkable cell on the current map" do
      {:ok, definition} = Catalog.by_id(26)
      stub(Cell, :random_traversable, fn "morocc" -> {:ok, {42, 77}} end)

      assert {:ok, updated} = AlTeleport.cast(@caster, :self, 1, definition)
      assert updated.pending_warp == {"morocc", 42, 77}
    end

    test "degrades gracefully when no walkable cell is found" do
      {:ok, definition} = Catalog.by_id(26)
      stub(Cell, :random_traversable, fn "morocc" -> {:error, :no_walkable_cell} end)

      assert {:ok, updated} = AlTeleport.cast(@caster, :self, 1, definition)
      assert updated.pending_warp == nil
    end

    test "degrades gracefully when map is not found" do
      {:ok, definition} = Catalog.by_id(26)

      stub(Cell, :random_traversable, fn "morocc" -> {:error, :not_found} end)

      assert {:ok, updated} = AlTeleport.cast(@caster, :self, 1, definition)
      assert updated.pending_warp == nil
    end
  end

  describe "cast/4 (lv2 — warp to save point)" do
    test "stages pending_warp to the caster's save point" do
      {:ok, definition} = Catalog.by_id(26)

      assert {:ok, updated} = AlTeleport.cast(@caster, :self, 2, definition)
      assert updated.pending_warp == {"prontera", 150, 190}
    end
  end
end
