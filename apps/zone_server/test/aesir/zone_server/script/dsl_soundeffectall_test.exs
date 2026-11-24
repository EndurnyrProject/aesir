defmodule Aesir.ZoneServer.Script.DslSoundEffectAllTest do
  @moduledoc """
  Covers the recipients of `soundeffectall`'s map-wide and map-rectangle forms
  (rAthena `buildin_soundeffectall`: `map_foreachinmap` and
  `map_foreachinallarea`), and their no-origin and errored-ctx no-ops.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.Factory

  alias Aesir.Net.SoundEffect
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    test_pid = self()

    stub(Broadcast, :to_players, fn char_ids, packet ->
      send(test_pid, {:to_players, Enum.sort(char_ids), packet})
      :ok
    end)

    SpatialIndex.add_player(1, 10, 10, "jupe_area1")
    SpatialIndex.add_player(2, 120, 200, "jupe_area1")
    SpatialIndex.add_player(3, 10, 10, "prontera")
    :ok
  end

  @packet %SoundEffect{name: "jupe_warning.wav", type: 0}

  defp detached_npc_ctx do
    %{build(:script_ctx) | char_id: nil, account_id: nil, game_state: nil, npc_gid: 0x5000_0001}
  end

  describe "soundeffectall/4 (whole map)" do
    test "plays for every player on the named map, from a detached NPC ctx" do
      ctx = detached_npc_ctx()

      assert Dsl.soundeffectall(ctx, "jupe_warning.wav", 0, "jupe_area1") == ctx
      assert_received {:to_players, [1, 2], @packet}
    end

    test "is a no-op without an origin unit (no player, no NPC)" do
      ctx = %{build(:script_ctx) | char_id: nil, npc_gid: nil}

      assert Dsl.soundeffectall(ctx, "jupe_warning.wav", 0, "jupe_area1") == ctx
      refute_received {:to_players, _, _}
    end

    test "is a no-op on an errored ctx" do
      ctx = %{detached_npc_ctx() | status: {:error, :boom}}

      assert Dsl.soundeffectall(ctx, "jupe_warning.wav", 0, "jupe_area1") == ctx
      refute_received {:to_players, _, _}
    end
  end

  describe "soundeffectall/5 (map rectangle)" do
    test "plays only for players inside the inclusive rectangle on that map" do
      ctx = detached_npc_ctx()

      assert Dsl.soundeffectall(ctx, "jupe_warning.wav", 0, "jupe_area1", {10, 10, 50, 50}) ==
               ctx

      assert_received {:to_players, [1], @packet}
    end

    test "accepts the corners in either order" do
      Dsl.soundeffectall(
        detached_npc_ctx(),
        "jupe_warning.wav",
        0,
        "jupe_area1",
        {50, 50, 10, 10}
      )

      assert_received {:to_players, [1], @packet}
    end

    test "is a no-op without an origin unit" do
      ctx = %{build(:script_ctx) | char_id: nil, npc_gid: nil}

      assert Dsl.soundeffectall(ctx, "jupe_warning.wav", 0, "jupe_area1", {0, 0, 300, 300}) ==
               ctx

      refute_received {:to_players, _, _}
    end
  end
end
