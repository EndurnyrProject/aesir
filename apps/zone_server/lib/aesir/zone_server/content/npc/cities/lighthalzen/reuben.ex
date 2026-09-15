defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Reuben do
  @moduledoc """
  Shares one of two random outbursts with visitors.

  ## Behavior

  - Randomly complains about Lighthalzen or tells the visitor to leave.

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
        x: 311,
        y: 194,
        dir: 3,
        sprite: 870,
        name: "Reuben",
        scope: :shared,
        unique_name: "Reuben#lhz_02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Enum.random(1..2) == 1 do
      ctx
      |> mes("[Reuben]")
      |> mes("Someday...")
      |> mes("Someday I just gotta")
      |> mes("become a train conductor")
      |> mes("and just get outta here!")
      |> mes("I really hate this place!")
      |> emotion(:anger)
      |> next()
      |> mes("[Reuben]]")
      |> mes("Wh-whoa...!")
      |> mes("Did you just hear")
      |> mes("me talk to myself?")
      |> mes("Crud! Don't be so nosy!")
      |> emotion(:fret)
      |> close()
    else
      ctx
      |> mes("[Reuben]")
      |> mes("Hey. What are")
      |> mes("you doing just")
      |> mes("looking at me?")
      |> mes("I don't know you")
      |> mes("from Adam, so get lost~")
      |> emotion(:rock)
      |> close()
    end
  end
end
