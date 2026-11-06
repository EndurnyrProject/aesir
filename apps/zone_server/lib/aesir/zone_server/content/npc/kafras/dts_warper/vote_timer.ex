defmodule Aesir.ZoneServer.Content.Npc.Kafras.DtsWarper.VoteTimer do
  @moduledoc """
  Invisible election clock in Einbroch that runs the Dungeon Teleport Service election.

  ## Behavior

  - Clears any leftover voting state on init and then ticks once a minute.
  - Counts the election minute by minute and tallies the votes when the voting window closes:
    either side reaching 20 votes ends the window, and the side with more votes takes the term.
  - Gives the term to the Kafra Corporation or to Cool Event Corp., announces the result and
    re-arms the service timer that keeps the new term running.
  - Records an empty election and starts over when fewer than 20 votes were cast.
  - While a term is running it only re-arms the service timer that matches the winner.

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
        y: 70,
        dir: 0,
        sprite: -1,
        name: "Vote Timer",
        scope: :shared,
        unique_name: "Vote Timer#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @election_timer "Vote Timer#ein::OnEnable"
  @kafra_timer "Vote Timer2#ein::OnEnable"
  @kafra_term_timer "Vote Timer3#ein::OnEnable"
  @cool_event_term_timer "Vote Timer4#ein::OnEnable"
  @kafra_result "Scrutiny Association#6::OnEnable"
  @cool_event_result "Scrutiny Association#7::OnEnable"

  @voting_minutes 1440
  @minimum_votes 20

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: ctx |> clear_voting_session() |> initnpctimer()
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnTimer60000", ctx), do: tick(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx |> clear_voting_session() |> initnpctimer()

  # A voting session left behind by a previous run must not carry over.
  defp clear_voting_session(ctx) do
    if Rathena.truthy?(get_server_var(ctx, "dts", 0)) do
      ctx
      |> set_server_var("dts", 0)
      |> set_server_var("dtsvote", 0)
      |> set_server_var("dtsday", 0)
    else
      ctx
    end
  end

  defp tick(ctx) do
    case get_server_var(ctx, "DTS_Result", 0) do
      1 -> ctx |> resume_term(@kafra_term_timer) |> stopnpctimer()
      2 -> ctx |> resume_term(@cool_event_term_timer) |> stopnpctimer()
      _election_pending -> count_minute(ctx)
    end
  end

  # Getting back in sync after a restart: keep the Kafra service timer until the Cool Event side
  # has won a term, then hand over to the timer that owns the running term.
  defp resume_term(ctx, term_timer) do
    cond do
      get_server_var(ctx, "DTS_JondaWins", 0) == 0 -> donpcevent(ctx, @kafra_timer)
      get_server_var(ctx, "DTS_KafraWins", 0) < 2 -> donpcevent(ctx, @kafra_timer)
      true -> donpcevent(ctx, term_timer)
    end
  end

  defp count_minute(ctx) do
    if get_server_var(ctx, "DTS_Time", 0) == @voting_minutes do
      tally(ctx)
    else
      ctx
      |> set_server_var("DTS_Time", get_server_var(ctx, "DTS_Time", 0) + 1)
      |> donpcevent(@election_timer)
    end
  end

  defp tally(ctx) do
    cool_event_votes = get_server_var(ctx, "DTS_JondaVotes", 0)
    kafra_votes = get_server_var(ctx, "DTS_KafraVotes", 0)

    cond do
      cool_event_votes < @minimum_votes and kafra_votes < @minimum_votes ->
        empty_election(ctx)

      cool_event_votes > kafra_votes ->
        kafra_takes_term(ctx)

      true ->
        cool_event_takes_term(ctx)
    end
  end

  defp empty_election(ctx) do
    ctx
    |> set_server_var("DTS_Result", 3)
    |> set_server_var("DTS_Time", 0)
    |> donpcevent(@election_timer)
  end

  defp kafra_takes_term(ctx) do
    cool_event_terms = get_server_var(ctx, "DTS_JondaWins", 0)
    kafra_terms = get_server_var(ctx, "DTS_KafraWins", 0)

    cond do
      # The reference does nothing here. It is unreachable: a side never holds more than two terms.
      cool_event_terms == 0 and kafra_terms > 2 ->
        ctx

      kafra_terms < 2 ->
        credit_kafra_term(ctx, @kafra_timer, increment: true)

      cool_event_terms == 0 ->
        credit_kafra_term(ctx, @kafra_timer)

      true ->
        credit_kafra_term(ctx, @kafra_term_timer)
    end
  end

  defp credit_kafra_term(ctx, next_timer, opts \\ []) do
    ctx =
      if Keyword.get(opts, :increment, false) do
        set_server_var(ctx, "DTS_KafraWins", get_server_var(ctx, "DTS_KafraWins", 0) + 1)
      else
        ctx
      end

    ctx
    |> set_server_var("DTS_Result", 1)
    |> set_server_var("DTS_Time", 0)
    |> donpcevent(@kafra_result)
    |> donpcevent(next_timer)
  end

  defp cool_event_takes_term(ctx) do
    cool_event_terms = get_server_var(ctx, "DTS_JondaWins", 0)
    kafra_terms = get_server_var(ctx, "DTS_KafraWins", 0)

    next_timer =
      cond do
        cool_event_terms < 2 -> @kafra_timer
        kafra_terms == 0 -> @kafra_timer
        true -> @cool_event_term_timer
      end

    ctx =
      if cool_event_terms < 2 do
        set_server_var(ctx, "DTS_JondaWins", cool_event_terms + 1)
      else
        ctx
      end

    ctx
    |> set_server_var("DTS_Result", 2)
    |> set_server_var("DTS_Time", 0)
    |> donpcevent(@cool_event_result)
    |> donpcevent(next_timer)
  end
end
