defmodule Aesir.ZoneServer.Npc.PacketsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Npc.Packets, as: NpcPackets

  setup :set_mimic_private
  setup :verify_on_exit!

  defmodule GuildlessNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 150, sprite: 58, name: "Guildless"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule GuildedNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 160, y: 160, sprite: 58, name: "Guarded"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def guild_id(_placement), do: 7
  end

  describe "spawn_packet/1" do
    test "an NPC without guild_id/1 spawns with no guild identity" do
      [placement] = GuildlessNpc.spawn()

      packet = NpcPackets.spawn_packet({GuildlessNpc, placement})

      assert %{guild_id: 0, guild_name: "", emblem_id: 0} = packet
    end

    test "an NPC declaring guild_id/1 spawns with the live guild's identity" do
      [placement] = GuildedNpc.spawn()

      expect(GuildManager, :get, fn 7 ->
        {:ok, %GuildState{guild_id: 7, name: "Sigrun", master_char_id: 1, emblem_id: 3}}
      end)

      packet = NpcPackets.spawn_packet({GuildedNpc, placement})

      assert %{guild_id: 7, guild_name: "Sigrun", emblem_id: 3} = packet
    end

    test "an NPC declaring guild_id/1 for a non-live guild keeps the id but blanks the display" do
      [placement] = GuildedNpc.spawn()

      expect(GuildManager, :get, fn 7 -> {:error, :not_found} end)

      packet = NpcPackets.spawn_packet({GuildedNpc, placement})

      assert %{guild_id: 7, guild_name: "", emblem_id: 0} = packet
    end
  end

  describe "vanish_packet/1" do
    test "builds a despawn packet keyed by the entity id" do
      %{gid: gid, reason: reason} = NpcPackets.vanish_packet(42)

      assert gid == 42
      assert reason
    end
  end
end
