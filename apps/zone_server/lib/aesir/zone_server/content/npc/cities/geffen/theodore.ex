defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Theodore do
  @moduledoc """
  Studies magic while searching for a weapon against long-ranged enemies.

  ## Credits

  - Original from rAthena, authors and Contributors
    - massdriller
    - Nexon
    - MasterOfMuppets
    - Silent
    - Musashiden
    - Evera
    - L0ne_W0lf
    - Lesbian
    - Lupus
    - Samuray22
    - DeadlySilence

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "geffen_in", x: 34, y: 170, dir: 0, sprite: 47, name: "Theodore", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Theodore]")
    |> mes("Hello!")
    |> mes("Isn't it a")
    |> mes("wonderful")
    |> mes("day today?")
    |> next()
    |> mes("[Theodore]")
    |> mes(
      "Well, I wouldn't know. I've been studying too hard to become a Mage. I've been staying up all night, agonizing over anything that's magical."
    )
    |> next()
    |> mes("[Theodore]")
    |> mes("*Sigh...*")
    |> mes("I especially worry about all the drawbacks to using magic.")
    |> next()
    |> mes("[Theodore]")
    |> mes(
      "Oh darn! It was really annoying when a long-ranged enemy found me the last time I went exploring. That crummy monster disrupted the casting of all my spells! I didn't hit it at all!"
    )
    |> next()
    |> mes("[Theodore]")
    |> mes(
      "After that, I realized I needed some sort of weapon to counter long-ranged attacks from enemies. Something that can attack from a distance..."
    )
    |> next()
    |> mes("[Theodore]")
    |> mes("Some sort of...")
    |> mes("Sharp, piercing")
    |> mes("projectile launcher, preferably made out of wood.")
    |> next()
    |> mes("[Theodore]")
    |> mes("But where could")
    |> mes("I find something")
    |> mes("like that?!")
    |> close()
  end
end
