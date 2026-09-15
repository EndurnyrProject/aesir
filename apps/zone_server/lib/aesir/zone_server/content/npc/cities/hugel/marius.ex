defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.Marius do
  @moduledoc """
  Boasts about Hugel's stubborn and long-lived elders.

  ## Credits

  - Original from rAthena, authors and Contributors
    - vicious_pucca
    - Poki#3
    - erKURITA
    - Munin

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hugel", x: 175, y: 115, dir: 5, sprite: 897, name: "Marius", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Marius]")
    |> mes("Yes, I'm an old man, but")
    |> mes("I can lick a whippersnapper")
    |> mes("like you any day of the week!")
    |> mes("You know, Hugel's got a longer")
    |> mes("life expectancy than all the other towns. You wanna know why?")
    |> next()
    |> mes("[Marius]")
    |> mes("It's because the old")
    |> mes("coots in this town refuse")
    |> mes("to just lay down and die!")
    |> mes("Now, c'mon! Lemme show")
    |> mes("you how strong I am! Let's")
    |> mes("wrestle or something, kid~")
    |> close()
  end
end
