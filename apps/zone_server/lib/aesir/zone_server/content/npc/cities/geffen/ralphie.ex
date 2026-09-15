defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Ralphie do
  @moduledoc """
  Lets slip his desire for a rare and destructive magical Staff.

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
    spawn: [%{map: "geffen", x: 147, y: 26, dir: 0, sprite: 97, name: "Ralphie", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Ralphie]")
    |> mes(
      "Somewhere in this world, there is a rare Staff which can transform psychic energy into physical force, endowing its owner with ^990000destructive power^000000..."
    )
    |> next()
    |> mes("[Ralphie]")
    |> mes(
      "With that, anyone could be as strong as Hercules... Even a weakling like me! Hahahahahah,"
    )
    |> mes("I must have it!")
    |> next()
    |> emotion(:surprise)
    |> mes("[Ralphie]")
    |> mes("...Good Heavens!")
    |> mes("Since when were")
    |> mes("you listening?")
    |> next()
    |> mes("[Ralphie]")
    |> mes("Did you happen")
    |> mes("to hear any of that?")
    |> mes("Muhwaha... ha. Ha.")
    |> next()
    |> mes("[Ralphie]")
    |> mes("Well...")
    |> mes("I didn't say anything. But if")
    |> mes("I did, forget all about it,")
    |> mes("whatever it was~")
    |> next()
    |> mes("[Ralphie]")
    |> mes("...Boy, this is awkward.")
    |> close()
  end
end
