defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Kid223165 do
  @moduledoc """
  Shares a child's observations about life in Veins.

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
        map: "veins",
        x: 223,
        y: 165,
        dir: 5,
        sprite: 944,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#ve4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Hey! Do you think")
    |> mes("I can reach the bridge")
    |> mes("over there if I jump")
    |> mes("from over here? Do")
    |> mes("you think you can try it?")
    |> next()
    |> mes("[Kid]")
    |> mes("What?! You can't do it?")
    |> mes("Well, I'm gonna be different")
    |> mes("when I grow up! I'm gonna")
    |> mes("be the world's best jumper!")
    |> mes("I'm gonna be able to jump")
    |> mes("all the way to the mooooon!")
    |> close()
  end
end
