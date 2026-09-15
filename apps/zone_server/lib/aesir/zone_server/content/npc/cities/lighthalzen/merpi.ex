defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Merpi do
  @moduledoc """
  Answers visitors' questions while tending laundry.

  ## Behavior

  - Discusses Lighthalzen, rumors of an axe murderer, or a shared interest in laundry.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 123,
        y: 212,
        dir: 4,
        sprite: 700,
        name: "Merpi",
        scope: :shared,
        unique_name: "Merpi#zen2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Merpi]")
      |> mes("Isn't the weather nice")
      |> mes("today? All this sunlight")
      |> mes("will dry these clothes")
      |> mes("quickly and give them")
      |> mes("a fresh, lovely scent.")
      |> next()
      |> mes("[Merpi]")
      |> mes("Oh, an adventurer from")
      |> mes("Rune-Midgarts, are you?")
      |> mes("How do you like our city?")
      |> mes("If you have any questions,")
      |> mes("feel free to ask me anything.")
      |> next()
      |> select(["Well, I have nothing to ask...", "Any news or rumors?", "I like laundry too."])

    case choice do
      1 ->
        ctx
        |> mes("[Merpi]")
        |> mes("Oh, really?")
        |> mes("Well, if you've traveled")
        |> mes("all over the world, maybe")
        |> mes("you've found a place just")
        |> mes("like Lighthalzen, so maybe")
        |> mes("you're already comfortable?")
        |> close()

      2 ->
        ctx
        |> mes("[Merpi]")
        |> mes("Well, things have")
        |> mes("been pretty peaceful")
        |> mes("for the past few years.")
        |> mes("The only rumor floating")
        |> mes("around is about some")
        |> mes("weird axe murderer...")
        |> close()

      3 ->
        ctx
        |> mes("[Merpi]")
        |> mes("Oh, that's wonderful!")
        |> mes("I so love doing hand")
        |> mes("laundry, though I'm not")
        |> mes("quite sure why. Oh well~")
        |> close()

      _ ->
        ctx
    end
  end
end
