defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Wizard.RoomOfEarth11697 do
  @moduledoc """
  Announces that a candidate failed the Room of Earth stage of the Wizard battle test and
  returns them to Geffen.

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
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Room of Earth#Failed")

  def on_event("OnTouch", ctx) do
    ctx
    |> mapannounce("job_wiz", "#{char_name(ctx, 0)} has not succeeded.", 1)
    |> warp("geffen", 120, 110)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
