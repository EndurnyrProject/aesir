defmodule Aesir.ZoneServer.Gm.Commands.AgitStart do
  @moduledoc """
  `@agitstart` - starts the WoE agit window: every FE castle is armed
  (`gvg` mapflag, Emperium summon) and the WoE-begun broadcast is sent.
  Level 99 GMs only.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Mmo.Woe.Server

  @impl true
  def name, do: "agitstart"

  @impl true
  def required_level, do: 99

  @impl true
  def execute(_args, _ctx) do
    Server.start()
    {:ok, "WoE started."}
  end
end
