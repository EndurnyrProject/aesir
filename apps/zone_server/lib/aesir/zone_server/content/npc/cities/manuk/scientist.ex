defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Scientist do
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
        x: 227,
        y: 280,
        dir: 5,
        sprite: 449,
        name: "Scientist",
        scope: :shared,
        unique_name: "Scientist#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx |> mes("[Scientist]") |> mes("Is there only one way we can survive..?") |> close()
    else
      ctx |> mes("[Apti]") |> mes("Dso piey pioit ioep ") |> close()
    end
  end
end
