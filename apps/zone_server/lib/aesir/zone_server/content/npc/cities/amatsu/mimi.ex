defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.Mimi do
  @moduledoc """
  Dreams of winning a future Miss Amatsu contest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 205,
        y: 163,
        dir: 3,
        sprite: 759,
        name: "Mimi",
        scope: :shared,
        unique_name: "Mimi#ama"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Mimi]")
    |> mes("Puhuhu~!")
    |> mes("Did you see Miss Amatsu near")
    |> mes("the Harbor? Isn't she")
    |> mes("preeeetty?")
    |> next()
    |> mes("[Mimi]")
    |> mes("I'm going to enter the Miss")
    |> mes("Amatsu Contest when I'm older.")
    |> next()
    |> mes("[Mimi]")
    |> mes("I'm sure that I'm the prettiest")
    |> mes("in this town but...")
    |> mes("A lady can always use a little more makeup.")
    |> close()
  end
end
