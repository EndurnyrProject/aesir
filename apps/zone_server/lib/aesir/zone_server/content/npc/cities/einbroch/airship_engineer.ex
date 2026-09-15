defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.AirshipEngineer do
  @moduledoc """
  Warns visitors away from a grounded airship named Burielle.

  ## Behavior

  - Explains the engineer's restoration work when asked about Burielle.
  - Responds differently to admiration and skepticism before dismissing the visitor.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 40,
        y: 116,
        dir: 1,
        sprite: 855,
        name: "Airship Engineer",
        scope: :shared,
        unique_name: "Airship Engineer#ein-1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airship Engineer]")
      |> mes("H-hey! Don't")
      |> mes("touch my precious")
      |> mes("Burielle! I just finished")
      |> mes("her tune-up and now she's")
      |> mes("sleeping! J-just step away!")
      |> next()
      |> select(["Who's Burielle?", "Sorry about That."])

    case choice do
      1 -> explain_burielle(ctx)
      2 -> dismiss_visitor(ctx)
      _ -> ctx
    end
  end

  defp explain_burielle(ctx) do
    {ctx, reaction} =
      ctx
      |> mes("[Airship Engineer]")
      |> mes("Burielle is the prettiest")
      |> mes("model among all the Airships")
      |> mes("made within the last ten years!")
      |> mes("She might be grounded now, but")
      |> mes("with my healing hands, she'll")
      |> mes("conquer the skies again!")
      |> next()
      |> select(["Ah~", "Uh huh..."])

    case reaction do
      1 -> admire_burielle(ctx)
      2 -> doubt_burielle(ctx)
      _ -> dismiss_visitor(ctx)
    end
  end

  defp admire_burielle(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Ah~")
    |> mes("I see, so you're")
    |> mes("working on restoring")
    |> mes("this magnificent specimen")
    |> mes("of an Airship. Best of luck~")
    |> next()
    |> mes("[Airship Engineer]")
    |> mes("Yeah. I'd appreciate")
    |> mes("it if you'd just be careful.")
    |> mes("I've put a lot of love into")
    |> mes("fixing up Burielle...")
    |> close()
  end

  defp doubt_burielle(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Uh huh...")
    |> mes("Right. For a second")
    |> mes("there, I thought you were")
    |> mes("talking about a person, but")
    |> mes("then I also assumed that you")
    |> mes("weren't, you know, a nutcase.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Oh, did you say,")
    |> mes("''prettiest model?''")
    |> mes("All Airships look the")
    |> mes("same to me, this one")
    |> mes("ain't special at all. You've")
    |> mes("gone loony tunes, paley boy.")
    |> next()
    |> emotion(:fret)
    |> mes("[Airship Engineer]")
    |> mes("Wh-what...?!")
    |> close()
  end

  defp dismiss_visitor(ctx) do
    ctx
    |> mes("[Airship Engineer]")
    |> mes("Well, at least you know")
    |> mes("what you did wrong. Now")
    |> mes("quit disturbing her and git!")
    |> close()
  end
end
