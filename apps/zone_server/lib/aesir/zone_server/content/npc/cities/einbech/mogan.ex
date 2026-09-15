defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.Mogan do
  @moduledoc """
  Warns travelers about Ungoliant and the mine cave-ins attributed to it.

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
        map: "einbech",
        x: 128,
        y: 238,
        dir: 5,
        sprite: 848,
        name: "Mogan",
        scope: :shared,
        unique_name: "Mogan#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Mogan]")
    |> mes("Recently, there were a few")
    |> mes("cave-ins where many miners")
    |> mes("were injured. It was discussed")
    |> mes("in the Town Council and in my")
    |> mes("opinion, I think the miners dug")
    |> mes("too deep and disturbed... ^FF0000it^000000.")
    |> next()
    |> mes("[Mogan]")
    |> mes("Yes, they awoke Ungoliant,")
    |> mes("the master of the caves that")
    |> mes("has existed since ancient time.")
    |> mes("I don't know how many more will")
    |> mes("be victimized by Ungoliant in the")
    |> mes("future. There's no telling...")
    |> next()
    |> mes("[Mogan]")
    |> mes("Adventurer, be careful")
    |> mes("if you travel inside the")
    |> mes("mines, lest your footsteps")
    |> mes("disturb Ungoliant's slumber.")
    |> close()
  end
end
