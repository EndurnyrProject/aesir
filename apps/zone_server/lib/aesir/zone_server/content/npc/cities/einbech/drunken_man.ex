defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.DrunkenMan do
  @moduledoc """
  Mumbles drunkenly inside the Einbech tavern.

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
        map: "ein_in01",
        x: 281,
        y: 85,
        dir: 3,
        sprite: 849,
        name: "Drunken Man",
        scope: :shared,
        unique_name: "Drunken Man#einbech"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Drunken Man]")
    |> mes("...^333333*Hiccup*^000000...")
    |> mes("^333333*Hiccup*^000000...")
    |> mes("^333333*Yawn*^000000.....")
    |> mes(".................")
    |> mes("..^333333*Hiccup*^000000.....")
    |> mes("^333333*Hiccup*^000000..")
    |> close()
  end
end
