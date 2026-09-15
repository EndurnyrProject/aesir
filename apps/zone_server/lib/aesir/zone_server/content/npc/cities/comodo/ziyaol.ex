defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Ziyaol do
  @moduledoc """
  Shares Ziyaol's life as a fisherman and concern for his daughter's ambitions.

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
        map: "cmd_fild04",
        x: 248,
        y: 86,
        dir: 4,
        sprite: 709,
        name: "Ziyaol",
        scope: :shared,
        unique_name: "Ziyaol#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Ziyaol]")
    |> mes("Ahhh, it's nice being")
    |> mes("a fisherman. You just")
    |> mes("relax and let the fish")
    |> mes("come to you. Well, it takes")
    |> mes("some skill to catch as much")
    |> mes("fish as I do with no effort~")
    |> next()
    |> mes("[Ziyaol]")
    |> mes("I like the leisure involved")
    |> mes("in my job, but if it's not one")
    |> mes("thing, it's another. Yeah, that")
    |> mes("daughter of mine over there")
    |> mes("won't stop harping about ")
    |> mes("moving to the biiig city.")
    |> next()
    |> mes("[Ziyaol]")
    |> mes("Why does she want to leave")
    |> mes("me so badly?! But if I don't")
    |> mes("let her go, she'll run away.")
    |> mes("What am I going to do with")
    |> mes("that girl? Well, I can't really")
    |> mes("stop her from dreaming...")
    |> close()
  end
end
