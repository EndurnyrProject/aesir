defmodule Aesir.ZoneServer.Content.Npc.Kafras.DtsWarper.ScrutinyAssociation24871 do
  @moduledoc """
  Invisible election scrutineer in Einbroch that announces the Dungeon Teleport Service election
  result step by step over fifteen seconds.

  ## Behavior

  - Announces that the votes are counted, then that the results are in.
  - Announces that Cool Event Corp. holds the Dungeon Teleport Service for the term, thanks the
    voters and stops its own timer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Silent
    - Lupus
    - L0ne_W0lf
    - Euphy
    - Liam

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script kafras/dts_warper.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 248,
        y: 71,
        dir: 0,
        sprite: -1,
        name: "Scrutiny Association",
        scope: :shared,
        unique_name: "Scrutiny Association#6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @color "0x70dbdb"
  @votes_counted "All the votes for the Dungeon Teleport Service Provider Election have been received and counted."
  @winner "This time, Cool Event Corp. will be the Dungeon Teleport Service Provider."
  @thanks "Many thanks to all of you who have voted and shown your support."

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnTimer1000", ctx), do: announce(ctx, @votes_counted, 0, @color)

  def on_event("OnTimer5000", ctx),
    do: announce(ctx, "The results are now in...", 0, @color)

  def on_event("OnTimer10000", ctx), do: announce(ctx, @winner, 0, @color)

  def on_event("OnTimer15000", ctx) do
    ctx
    |> announce(@thanks, 0, @color)
    |> stopnpctimer()
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: initnpctimer(ctx)
end
