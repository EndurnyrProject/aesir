defmodule Aesir.ZoneServer.Npc.NpcSpawnIntegrationTest do
  @moduledoc """
  End-to-end static NPC visibility at the session level (no real client).

  Mirrors the warp visibility path: a registered `Npc.Registry` placement on the
  player's map, within view range, is sent to the player as a `UnitSpawn` with
  `object_type` npc when `MovementHandler.handle_visibility_update/1` runs. The
  returned state tracks the NPC's synthetic unit id in `visible_npcs`, and that
  unit id resolves back to its module via `Registry.module_for_unit/1`.

  Drives the real `MovementHandler` + `Npc.Registry`; only the I/O collaborators
  (spatial index bookkeeping, unit registry lookups) are stubbed. `prontera`
  uses the real map cache warmed by `TestEtsSetup`.
  """

  use ExUnit.Case, async: false
  use Mimic

  @moduletag :integration

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @char_id 2001

  defmodule SpawnableNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 152, y: 151, dir: 6, sprite: 58, name: "Greeter"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    on_exit(fn -> :persistent_term.erase(Registry) end)
    Registry.reload([SpawnableNpc])

    stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
    stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
    stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
    stub(Broadcast, :to_players, fn _, _, _ -> :ok end)

    :ok
  end

  describe "static NPC visibility on map entry" do
    test "a player near a registered NPC receives a UnitSpawn for it (object type npc)" do
      placement = hd(SpawnableNpc.spawn())
      gid = Registry.entity_id(placement)

      game_state =
        %{PlayerState.new(character()) | x: 150, y: 150}

      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      assert_received {:"$gen_cast",
                       {:send_packet,
                        %UnitSpawn{
                          object_type: object_type,
                          gid: ^gid,
                          x: 152,
                          y: 151,
                          job: 58,
                          name: "Greeter"
                        }}}

      assert object_type == ObjectType.npc()
      assert MapSet.member?(new_state.visible_npcs, gid)
    end

    test "the spawned NPC's unit id resolves back to its module" do
      placement = hd(SpawnableNpc.spawn())
      gid = Registry.entity_id(placement)

      assert {:ok, {SpawnableNpc, ^placement}} = Registry.module_for_unit(gid)
    end

    test "an NPC outside view range is not sent" do
      game_state = %{PlayerState.new(character()) | x: 10, y: 10}
      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      refute_received {:"$gen_cast", {:send_packet, %UnitSpawn{job: 58}}}
      assert MapSet.size(new_state.visible_npcs) == 0
    end
  end

  defp character do
    %Character{
      id: @char_id,
      account_id: 200,
      name: "Wanderer",
      last_map: @map,
      last_x: 150,
      last_y: 150,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end

  defp register_player(game_state) do
    UnitRegistry.register_unit(:player, @char_id, PlayerState, game_state, self())
  end
end
