defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.Citizen do
  @moduledoc """
  Welcomes visitors and recounts a sighting of an unusual Poring.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 212,
        y: 122,
        dir: 4,
        sprite: 97,
        name: "Citizen",
        scope: :shared,
        unique_name: "Citizen#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gavin]")
      |> mes("Welcome!")
      |> mes("The town of")
      |> mes("Al De Baran")
      |> mes("welcomes you!")
      |> next()
      |> mes("[Gavin]")
      |> mes("Well, that might be an exaggeration. After all, it's just me that's welcoming you.")
      |> mes("Hey there!")
      |> next()
      |> select(["Now, tell me about monsters.", "End conversation."])

    if choice == 1 do
      ctx
      |> mes("[Gavin]")
      |> mes("Monsters...?")
      |> mes(
        "Aren't we straying off topic a little bit? Ah, you must be one of those adventurers!"
      )
      |> next()
      |> mes("[Gavin]")
      |> mes(
        "Can't get your mind off the job, eh? Alright, now there was some monster that I saw just recently..."
      )
      |> next()
      |> mes("[Gavin]")
      |> mes(
        "Ah, now I remember! Just a few days ago, I saw a really interesting looking monster! It was a Poring with Angel's wings!"
      )
      |> next()
      |> mes("[Gavin]")
      |> mes(
        "I swear! He was jumping around somewhere near Mt. Mjolnir with some ordinary Porings. I think he was, like, their leader."
      )
      |> close()
    else
      ctx
      |> mes("[Gavin]")
      |> mes("Awww...")
      |> mes("Don't be too disappointed that there's only one person in your welcome wagon!")
      |> close()
    end
  end
end
