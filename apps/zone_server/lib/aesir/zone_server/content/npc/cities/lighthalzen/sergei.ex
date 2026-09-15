defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Sergei do
  @moduledoc """
  Offers to recount the Weapon Shop's Serial Axe Murderer story.

  ## Behavior

  - Tells the story when asked or reacts to the visitor declining it.

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
        x: 192,
        y: 63,
        dir: 4,
        sprite: 92,
        name: "Sergei",
        scope: :shared,
        unique_name: "Sergei#zen1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sergei]")
      |> mes("You know, there's an")
      |> mes("interesting story about")
      |> mes("the axe that's hanging")
      |> mes("over there. Would you")
      |> mes("like me to tell you?")
      |> next()
      |> select(["Sure.", "No, thanks."])

    if choice == 1 do
      ctx
      |> mes("[Sergei]")
      |> mes("This previous owner of")
      |> mes("this Weapon Shop was")
      |> mes("a convicted serial killer.")
      |> mes("Each night, he'd take that")
      |> mes("axe and cruelly murder")
      |> mes("beautiful ladies like me.")
      |> next()
      |> mes("[Sergei]")
      |> mes("When he was finally")
      |> mes("caught, they beheaded")
      |> mes("him with his own axe.")
      |> mes("Since then, they say that")
      |> mes("his ghost still lingers and")
      |> mes("sharpens this axe at night.")
      |> next()
      |> mes("[Sergei]")
      |> mes("Just thinking about")
      |> mes("it gives me goosebumps!")
      |> mes("And I'm supposed to work")
      |> mes("here! It's so creepy!")
      |> close()
    else
      ctx
      |> mes("[Sergei]")
      |> mes("Oh, how disappointing~")
      |> mes("It's the perfect story for")
      |> mes("the season. Well, now that")
      |> mes("I think about it, that story is")
      |> mes("actually pretty creepy...")
      |> close()
    end
  end
end
