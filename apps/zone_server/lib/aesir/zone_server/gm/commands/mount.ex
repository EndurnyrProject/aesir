defmodule Aesir.ZoneServer.Gm.Commands.Mount do
  @moduledoc """
  `@mount` - toggles the calling GM's Peco-Peco mount as a testing tool: if
  mounted, dismounts; otherwise mounts, bypassing the `KN_RIDING` learned gate
  (the alive/already-mounted gates still apply). Delivery is
  `PlayerSession.gm_toggle_mount/1` on the caller's own session.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @impl true
  def name, do: "mount"

  @impl true
  def required_level, do: 60

  @impl true
  def execute(_args, ctx) do
    message = if MountHandler.riding?(ctx), do: "Dismounted", else: "Mounted"

    PlayerSession.gm_toggle_mount(self())
    {:ok, message}
  end
end
