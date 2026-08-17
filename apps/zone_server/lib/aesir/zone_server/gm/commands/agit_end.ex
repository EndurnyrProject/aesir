defmodule Aesir.ZoneServer.Gm.Commands.AgitEnd do
  @moduledoc """
  `@agitend` - ends the WoE agit window: every FE castle is disarmed
  (Emperium despawn, `gvg` cleared) and the WoE-ended broadcast plus owners
  roll-call is sent. Level 99 GMs only.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Mmo.Woe.Server

  @impl true
  def name, do: "agitend"

  @impl true
  def required_level, do: 99

  @impl true
  def execute(_args, _ctx) do
    Server.stop()
    {:ok, "WoE ended."}
  end
end
