defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Customer17014 do
  @moduledoc """
  Portrays the taciturn Bachewcca drinking in the Prontera pub.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 170,
        y: 14,
        dir: 0,
        sprite: 89,
        name: "Customer",
        scope: :shared,
        unique_name: "Customer#Bachewcca"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Bachewcca]")
    |> mes("..............")
    |> mes("^666666*Gulp....gulp...*^000000")
    |> mes("Grrrrr!! That hit the spot!")
    |> emotion(:cry)
    |> close()
  end
end
