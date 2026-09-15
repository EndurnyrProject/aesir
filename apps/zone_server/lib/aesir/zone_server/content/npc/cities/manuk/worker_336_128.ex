defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Worker336128 do
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
        x: 336,
        y: 128,
        dir: 5,
        sprite: 454,
        name: "Worker",
        scope: :shared,
        unique_name: "Worker#ep13bsg5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx |> mes("[Worker]") |> mes("Isn't this fabulous?") |> close()
    else
      ctx |> mes("[Worker]") |> mes("R tt osj dj d") |> close()
    end
  end
end
