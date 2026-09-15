defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner190215 do
  @moduledoc """
  Shares a resident's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 190,
        y: 215,
        dir: 3,
        sprite: 946,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve22"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Well, our town doesn't")
    |> mes("have a choice but to")
    |> mes("defend itself in dangerous")
    |> mes("times. The young men we")
    |> mes("have here are all buff and")
    |> mes("tough to protect us.")
    |> next()
    |> mes("[Town]")
    |> mes("They may not be beautiful,")
    |> mes("but they have kind and")
    |> mes("gentle hearts. It's a pity")
    |> mes("that the women here")
    |> mes("are more concerned")
    |> mes("with appearances.")
    |> next()
    |> mes("[Towner]")
    |> mes("Don't judge a book")
    |> mes("by its cover, but")
    |> mes("by its contents.")
    |> close()
  end
end
