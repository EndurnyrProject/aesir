defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.CoolEventStaff36284 do
  @moduledoc """
  Shows Cesuna avoiding work while thinking about Saera.

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
        map: "lhz_in02",
        x: 36,
        y: 284,
        dir: 0,
        sprite: 874,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#Cesuna"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Cesuna]")
    |> mes("Ack! I'm totally")
    |> mes("swamped with all this")
    |> mes("work! But I don't wanna")
    |> mes("do any of it. That's it!")
    |> mes("I totally need a break.")
    |> next()
    |> mes("[Cesuna]")
    |> mes("^333333*Sigh...*^000000")
    |> mes("I wonder if Saera")
    |> mes("would ever consider")
    |> mes("going out with me?")
    |> mes("That would be nice~")
    |> close()
  end
end
