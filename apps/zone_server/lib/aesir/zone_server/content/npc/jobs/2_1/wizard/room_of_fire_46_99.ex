defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Wizard.RoomOfFire4699 do
  @moduledoc """
  Returns a candidate who failed the Room of Fire stage of the Wizard battle test to
  Geffen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - yoshiki
    - kobra_k88
    - Lupus
    - L0ne_W0lf
    - Yommy
    - SoulBlaker
    - Kisuka
    - Vali
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Room of Fire#Failed")

  def on_event("OnTouch", ctx), do: warp(ctx, "geffen", 120, 110)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
