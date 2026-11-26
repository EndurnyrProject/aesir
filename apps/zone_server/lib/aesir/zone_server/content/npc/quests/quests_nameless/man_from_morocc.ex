defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.ManFromMorocc do
  @moduledoc """
  A traveler shares rumors about Rogue agents.

  ## Behavior

  - Starts the rumor investigation and responds to its progress.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 163,
        y: 204,
        dir: 3,
        sprite: 99,
        name: "Man from Morocc",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rumour_nd, 0) == 0 ->
        start_conversation(ctx)

      get_char_var(ctx, :rumour_nd, 0) == 1 ->
        ctx
        |> mes("[Morocc Traveler]")
        |> mes("Shouldn't you be")
        |> mes("looking for a Rogue")
        |> mes("agent to talk to?")
        |> mes("I mean, maybe you")
        |> mes("can pitch in and")
        |> mes("help them out.")
        |> close()

      get_char_var(ctx, :rumour_nd, 0) > 1 and get_char_var(ctx, :zdan_edq, 0) > 12 ->
        ctx
        |> mes("[Morocc Traveler]")
        |> mes("So the Z Gang was what")
        |> mes("those crazy rumors were")
        |> mes("all about. Good to hear")
        |> mes("that they're all in jail.")
        |> close()

      get_char_var(ctx, :rumour_nd, 0) > 1 ->
        ctx
        |> mes("[Morocc Traveler]")
        |> mes("Hey, uh...")
        |> mes("I'm just trying to")
        |> mes("relax on my vacation.")
        |> close()

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp start_conversation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Morocc Traveler]")
      |> mes("Ah, it's very nice and")
      |> mes("refreshing to be near this")
      |> mes("fountain. It's much cooler")
      |> mes("here than back in Morocc.")
      |> next()
      |> select(["Nice day today, huh?", "How's Morocc lately?"])

    case choice do
      1 ->
        ctx
        |> mes("[Morocc Traveler]")
        |> mes("Oh, yes. It's a wonderful")
        |> mes("day! Prontera is so sunny")
        |> mes("and cool. No wonder so")
        |> mes("many people live over here!")
        |> close()

      2 ->
        ctx =
          ctx
          |> mes("[Morocc Traveler]")
          |> mes("You're an adventurer, and")
          |> mes("you haven't heard the crazy")
          |> mes("rumors spreading all over")
          |> mes("the Rune-Midgarts kingdom?")
          |> mes("I thought you guys traveled")
          |> mes("around and heard things.")
          |> next()

        {ctx, _} = select(ctx, ["What crazy rumors?"])

        ctx
        |> mes("[Morocc Traveler]")
        |> mes("Uh... Rogue agents!")
        |> mes("They're all over the place!")
        |> mes("Why don't you talk to some")
        |> mes("of the Rogue agents dispatched")
        |> mes("in the other towns? Then you'll")
        |> mes("know what I'm talking about!")
        |> set_char_var(:rumour_nd, 1)
        |> close()

      _ ->
        ctx
    end
  end
end
