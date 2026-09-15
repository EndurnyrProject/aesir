defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.VolunteerMorocc88133 do
  @moduledoc """
  Pleads for help with Morocc’s overwhelming restoration work.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 88,
        y: 133,
        dir: 3,
        sprite: 748,
        name: "Volunteer - Morocc",
        scope: :shared,
        unique_name: "Volunteer - Morocc#02"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Morocc Volunteer]")
    |> mes("We're... We're flooded with work...")
    |> next()
    |> mes("[Morocc Volunteer]")
    |> mes("This work's like never-ending, no matter how hard we try!!!")
    |> mes("People of Rune-Midgarts!! Please lend us a helping hand!!")
    |> next()
    |> mes("[Morocc Volunteer]")
    |> mes("Haw.... Whew... Ugh...")
    |> close()
  end
end
