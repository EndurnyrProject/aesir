defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Meera do
  @moduledoc """
  Welcomes visitors to Geffen and praises Honey and Royal Jelly.

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
    spawn: [%{map: "geffen", x: 59, y: 143, dir: 0, sprite: 91, name: "Meera", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Meera]")
    |> mes("Welcome to Geffen,")
    |> mes("the City of Magic!")
    |> next()
    |> mes("[Meera]")
    |> mes(
      "I don't know much about magic, but do you know what tastes magical? ^CC6600Honey^000000!"
    )
    |> next()
    |> mes("[Meera]")
    |> mes(
      "It's soooo sweet and delicious. I'm not sure if it's an aphrodisiac, but I know for a fact that it will relieve you of fatigue and help you recover from wounds!"
    )
    |> next()
    |> mes("[Meera]")
    |> mes(
      "Hornets living in the grasslands spend their lives gathering nectar at the Queen Bee's command. Honey is made from the nectar they gather."
    )
    |> next()
    |> mes("[Meera]")
    |> mes(
      "But that's not all. There's a special kind of honey that's made for only Queen Bees to eat:"
    )
    |> mes("^CC6600Royal Jelly^000000!")
    |> next()
    |> mes("[Meera]")
    |> mes(
      "Nothing can compare to the luscious flavor of Royal Jelly. And I think it's even better for you than ordinary Honey!"
    )
    |> close()
  end
end
