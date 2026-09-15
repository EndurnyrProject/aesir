defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Mechanic do
  @moduledoc """
  Shares a Manuk resident's remarks according to whether the visitor understands the local language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "man_in01",
        x: 360,
        y: 137,
        dir: 5,
        sprite: 454,
        name: "Mechanic",
        scope: :shared,
        unique_name: "Mechanic#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Mechanic]")
      |> mes("Alien races are not allowed to enter.")
      |> mes("It's very dangerous here, please don't come any closer.")
      |> close()
    else
      ctx |> mes("[Asoui]") |> mes("Fs iua sdjosow ww ") |> mes("Adds wwpq iusnd ") |> close()
    end
  end
end
