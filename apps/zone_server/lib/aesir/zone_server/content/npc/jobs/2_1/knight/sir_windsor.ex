defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.SirWindsor do
  @moduledoc """
  Taciturn Knight who runs the third Knight job test, a timed three-stage combat trial.

  ## Behavior

  - Sends candidates who passed Sir Siracuse's test, or who failed his own, to
    the combat test arena and advances the quest log.
  - Brushes off candidates who are not yet at his test or have already passed it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 79,
        y: 94,
        dir: 4,
        sprite: 733,
        name: "Sir Windsor",
        scope: :shared,
        unique_name: "Sir Windsor#knt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> next()
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Sir Windsor]")

    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:swordman) do
      ctx |> greet_non_swordman() |> close()
    else
      talk_about_test(ctx, get_char_var(ctx, :KNIGHT_Q, 0))
    end
  end

  defp greet_non_swordman(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) -> mes(ctx, "Protect.")
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) -> send_novice_away(ctx)
      true -> mes(ctx, "...Hmpf.")
    end
  end

  defp send_novice_away(ctx), do: ctx |> mes("...Go play") |> mes("outside.")

  defp talk_about_test(ctx, quest) do
    cond do
      quest == 0 -> ctx |> mes("...What?") |> close()
      quest >= 1 and quest <= 5 -> refuse_early_candidate(ctx)
      quest == 6 or quest == 7 -> offer_combat_test(ctx, quest)
      quest == 14 -> ctx |> mes("...Talk to") |> mes("the captain.") |> close()
      true -> ctx |> mes("...You're") |> mes("done here.") |> close()
    end
  end

  defp refuse_early_candidate(ctx) do
    {ctx, choice} =
      ctx
      |> mes("...What?")
      |> next()
      |> select(["I would like to take the test to change jobs.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> next()
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Sir Windsor]")
      |> mes("...It's not my turn.")
      |> close()
    else
      silent_dismissal(ctx)
    end
  end

  defp offer_combat_test(ctx, quest) do
    {ctx, options} =
      if quest == 6 do
        {ctx |> mes(".....What?") |> next(), ["Sir Siracuse sent me to you.", "Oh, nothing."]}
      else
        {next(ctx), ["I want to try again!", "..."]}
      end

    {ctx, choice} = select(ctx, options)

    if choice == 1 do
      send_to_arena(ctx)
    else
      silent_dismissal(ctx)
    end
  end

  defp send_to_arena(ctx) do
    ctx =
      ctx
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> next()
      |> set_char_var(:KNIGHT_Q, 7)

    ctx = if checkquest(ctx, 9004) != -1, do: changequest(ctx, 9004, 9005), else: ctx

    ctx =
      ctx
      |> mes("[Sir Windsor]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Sir Windsor]")
      |> lead_the_way()
      |> close()

    ctx = if checkquest(ctx, 9006) == -1, do: changequest(ctx, 9005, 9006), else: ctx

    warp(ctx, "job_knt", 89, 101)
  end

  defp lead_the_way(ctx) do
    if get_char_var(ctx, :KNIGHT_Q, 0) == 6 do
      mes(ctx, "...Follow me.")
    else
      ctx |> mes("...Fine.") |> next() |> mes("[Sir Windsor]") |> mes("...This way.")
    end
  end

  defp silent_dismissal(ctx), do: ctx |> mes("[Sir Windsor]") |> mes("...") |> close()
end
