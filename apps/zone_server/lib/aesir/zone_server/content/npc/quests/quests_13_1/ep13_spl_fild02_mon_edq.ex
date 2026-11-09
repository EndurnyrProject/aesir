defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Ep13SplFild02MonEdq do
  @moduledoc """
  The invisible Splendid field spawner of the expedition's field quest, which keeps a batch of
  monsters alive and drops a report sheet for the kill that empties it.

  ## Behavior

  - On boot and on a click reveals itself and starts the spawn batch.
  - Every ten minutes clears the batch and spawns it again.
  - Drops a Report Sheet on a kill while the batch is not yet exhausted and the player is on
    quest step 71 or 72.
  - On disable stops the timer, clears the batch and hides itself.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_fild02",
        x: 1,
        y: 1,
        dir: 0,
        sprite: -1,
        name: "ep13_spl_fild02_mon_edq",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "ep13_spl_fild02_mon_edq"
  @map "spl_fild02"
  @event "ep13_spl_fild02_mon_edq::OnMyMobDead"
  @report_sheet 6040
  @spawn_batch 14

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: arm(ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: arm(ctx)

  def on_event("OnEnable", ctx) do
    ctx
    |> summon_mob(
      mob_id: 1994,
      map: @map,
      at: :random,
      amount: 7,
      event: @event
    )
    |> summon_mob(
      mob_id: 1995,
      map: @map,
      at: :random,
      amount: 7,
      event: @event
    )
    |> initnpctimer()
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> stopnpctimer()
    |> killmonster(@map, @event)
    |> disablenpc(@npc)
  end

  def on_event("OnTimer600000", ctx) do
    ctx
    |> killmonster(@map, @event)
    |> stopnpctimer()
    |> donpcevent("#{@npc}::OnEnable")
  end

  # A report sheet drops only while the spawn batch is not yet exhausted and the player is
  # chasing it on the matching quest step.
  def on_event("OnMyMobDead", ctx) do
    if mobcount(ctx, @map, @event) < @spawn_batch and
         get_char_var(ctx, :ep13_1_edq, 0) in [71, 72] do
      give_item(ctx, @report_sheet, 1)
    else
      ctx
    end
  end

  defp arm(ctx) do
    ctx
    |> enablenpc(@npc)
    |> donpcevent("ep13_spl_fild02_mon_edq::OnEnable")
  end
end
