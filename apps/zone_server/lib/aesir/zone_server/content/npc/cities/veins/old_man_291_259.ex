defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.OldMan291259 do
  @moduledoc """
  Shares an elderly resident's observations about life in Veins.

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
        x: 291,
        y: 259,
        dir: 3,
        sprite: 945,
        name: "Old Man",
        scope: :shared,
        unique_name: "Old Man#ve4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Old Man]")
    |> mes("Fr... Fr...")
    |> next()
    |> mes("[Old Man]")
    |> mes("Fr...")
    |> next()
    |> mes("[Old Man]")
    |> mes("Praise Freya! ^333333*Keck*^000000")
    |> mes("^333333*Cough cough*^000000 Fre...")
    |> mes("^333333*Cough*^000000 Praise Freya!")
    |> mes("Freya! Conquer those")
    |> mes("that blaspheme you! Let")
    |> mes("me see it before I die!")
    |> next()
    |> mes("[Old Man]")
    |> mes("I have never regretted")
    |> mes("^333333*Cough*^000000 my faith in you,")
    |> mes("my goddess! ^333333*Keck*^000000 May")
    |> mes("the suffering of all our")
    |> mes("enemies drive them to")
    |> mes("madness before death!")
    |> close()
  end
end
