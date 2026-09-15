defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.Kinos do
  @moduledoc """
  Struggles to open the door to a house in Rachel.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 209,
        y: 198,
        dir: 3,
        sprite: 921,
        name: "Kinos",
        scope: :shared,
        unique_name: "Kinos#aru"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("If you open this door, you")
    |> mes("can go inside this house,")
    |> mes("and live in one of the rooms!")
    |> mes("Then, you can add your couches")
    |> mes("and a bed, and all of your stuff!")
    |> next()
    |> mes("[Kid]")
    |> mes("All you gotta do is...")
    |> mes("Ugh! Turn this knob")
    |> mes("and... Grrrrah! Open")
    |> mes("this door... But it's")
    |> mes("almost impossible..")
    |> close()
  end
end
