defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.Npc do
  @moduledoc """
  Returns bungee jump survivors to Umbala.

  ## Behavior

  - Warps touching players back to the village.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: warp(ctx, "umbala", 145, 166)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
