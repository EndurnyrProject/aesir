defmodule Aesir.ZoneServer.Gm.Commands.PvpOff do
  @moduledoc """
  `@pvpoff` - disables PvP on the current GM's map.

  Lays an overlay-false for all three PvP flags (rather than `clear_runtime`) so
  the command also turns off a statically-PvP map. The overlay survives until
  cleared, matching how WoE's `gvg` flag behaves. Level 99 GMs only.
  """

  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Map.MapFlags

  @impl true
  def name, do: "pvpoff"

  @impl true
  def required_level, do: 99

  @impl true
  def execute(_args, ctx) do
    map = ctx.game_state.map_name

    MapFlags.set_runtime(map, :pvp, false)
    MapFlags.set_runtime(map, :pvp_noparty, false)
    MapFlags.set_runtime(map, :pvp_noguild, false)

    {:ok, "PvP disabled."}
  end
end
