defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Bijou69105 do
  @moduledoc """
  Timer that choreographs the one-minute Dancer job test performance.

  ## Behavior

  - Announces each dance move to the arena while opening every tile except the one the candidate
    must stand on, then closes all tiles and cues the backdancers.
  - Ends the routine by spawning the Poring target and enabling the arena exits.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kalen
    - Fredzilla
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka
    - Euphy
    - Vicious
    - Lance
    - Skotlex

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @dance_tiles ["dance#up", "dance#down", "dance#left", "dance#right", "dance#cen"]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnDisable", ctx), do: stopnpctimer(ctx)

  def on_event("OnTimer2000", ctx) do
    mapannounce(ctx, "job_duncer", "Okay, let's begin. Now relax, the test is 1 minute~", 1)
  end

  def on_event("OnTimer5000", ctx), do: mapannounce(ctx, "job_duncer", " Up!", 1)
  def on_event("OnTimer7000", ctx), do: open_tiles_except(ctx, "dance#up")
  def on_event("OnTimer8000", ctx), do: cue_move(ctx, " Down!")
  def on_event("OnTimer11000", ctx), do: open_tiles_except(ctx, "dance#down")
  def on_event("OnTimer12000", ctx), do: cue_move(ctx, " Left~!")
  def on_event("OnTimer15000", ctx), do: open_tiles_except(ctx, "dance#left")
  def on_event("OnTimer16000", ctx), do: cue_move(ctx, " Left, then Right~!")
  def on_event("OnTimer19000", ctx), do: open_tiles_except(ctx, "dance#right")
  def on_event("OnTimer20000", ctx), do: cue_move(ctx, " Back to the Center~ !")
  def on_event("OnTimer23000", ctx), do: open_tiles_except(ctx, "dance#cen")

  def on_event("OnTimer23500", ctx) do
    ctx
    |> donpcevent("Backdancer#1::OnSmile")
    |> mapannounce("job_duncer", " Hold in place... ", 1)
  end

  def on_event("OnTimer27000", ctx) do
    ctx
    |> donpcevent("Backdancer#1::OnSmile")
    |> mapannounce("job_duncer", " Hold then 'Improve Concentration!'", 1)
  end

  def on_event("OnTimer28500", ctx), do: mapannounce(ctx, "job_duncer", " Pay attention! ", 1)
  def on_event("OnTimer30000", ctx), do: cue_move(ctx, " Left!")
  def on_event("OnTimer34000", ctx), do: open_tiles_except(ctx, "dance#left")
  def on_event("OnTimer35000", ctx), do: cue_move(ctx, " Down!")

  def on_event("OnTimer38500", ctx) do
    mapannounce(ctx, "job_duncer", " Down, then Right~ ", 1)
  end

  def on_event("OnTimer40000", ctx) do
    ctx
    |> open_tiles_except("dance#right")
    |> mapannounce("job_duncer", " Hold it~", 1)
  end

  def on_event("OnTimer43000", ctx), do: cue_move(ctx, " Left, Center, Right, Up!")
  def on_event("OnTimer49000", ctx), do: open_tiles_except(ctx, "dance#up")
  def on_event("OnTimer50000", ctx), do: cue_move(ctx, " Right!")
  def on_event("OnTimer53000", ctx), do: open_tiles_except(ctx, "dance#right")
  def on_event("OnTimer54000", ctx), do: cue_move(ctx, " Left, Center, Down, Up~! ")
  def on_event("OnTimer60000", ctx), do: open_tiles_except(ctx, "dance#up")
  def on_event("OnTimer61000", ctx), do: cue_move(ctx, " Once again~ Left, Center, Down, Up~ ! ")
  def on_event("OnTimer66000", ctx), do: open_tiles_except(ctx, "dance#up")
  def on_event("OnTimer67000", ctx), do: cue_move(ctx, " Down~!")
  def on_event("OnTimer69000", ctx), do: open_tiles_except(ctx, "dance#down")
  def on_event("OnTimer70000", ctx), do: cue_move(ctx, " Left!")
  def on_event("OnTimer74000", ctx), do: open_tiles_except(ctx, "dance#left")
  def on_event("OnTimer75000", ctx), do: cue_move(ctx, " Center!")
  def on_event("OnTimer80000", ctx), do: open_tiles_except(ctx, "dance#cen")
  def on_event("OnTimer81000", ctx), do: cue_move(ctx, " Okay, Finish~ 'Arrow Shower!'")
  def on_event("OnTimer82000", ctx), do: donpcevent(ctx, "dance#poring::OnEnable")

  def on_event("OnTimer89000", ctx) do
    ctx |> donpcevent("dance#poring::OnDisable") |> donpcevent("dance#return::OnEnable")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp open_tiles_except(ctx, closed_tile) do
    Enum.reduce(@dance_tiles, ctx, fn
      ^closed_tile, ctx -> disablenpc(ctx, closed_tile)
      tile, ctx -> enablenpc(ctx, tile)
    end)
  end

  defp cue_move(ctx, announcement) do
    ctx = donpcevent(ctx, "Backdancer#1::OnSmile")

    @dance_tiles
    |> Enum.reduce(ctx, &disablenpc(&2, &1))
    |> mapannounce("job_duncer", announcement, 1)
  end
end
