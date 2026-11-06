defmodule Aesir.ZoneServer.Content.Npc.Kafras.DtsWarper.VoteTimer3 do
  @moduledoc """
  Invisible service clock in Einbroch for a Kafra Corporation Dungeon Teleport Service term.

  ## Behavior

  - Ticks once a minute and re-arms itself.
  - At the end of the 8,640-minute term it clears the election state, gives back the Cool Event
    term the reference counts, counts the ended term and hands over to the election clock.

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
        x: 246,
        y: 71,
        dir: 0,
        sprite: -1,
        name: "Vote Timer3",
        scope: :shared,
        unique_name: "Vote Timer3#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @term_minutes 8640
  @election_timer "Vote Timer#ein::OnEnable"
  @service_timer "Vote Timer3#ein::OnEnable"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnTimer60000", ctx), do: tick(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: initnpctimer(ctx)

  defp tick(ctx) do
    ctx = stopnpctimer(ctx)

    if get_server_var(ctx, "DTS_PeriodCheck", 0) == @term_minutes do
      votes_counted = get_server_var(ctx, "DTS_VoteCount", 0) + 1

      ctx
      |> set_server_var("DTS_PeriodCheck", 0)
      |> set_server_var("DTS_Result", 0)
      |> set_server_var("DTS_KafraVotes", 0)
      |> set_server_var("DTS_JondaVotes", 0)
      |> set_server_var("DTS_JondaWins", get_server_var(ctx, "DTS_JondaWins", 0) - 1)
      |> set_server_var("DTS_VoteCount", votes_counted)
      |> donpcevent(@election_timer)
    else
      ctx
      |> set_server_var("DTS_PeriodCheck", get_server_var(ctx, "DTS_PeriodCheck", 0) + 1)
      |> donpcevent(@service_timer)
    end
  end
end
