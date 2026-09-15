defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Worker393134 do
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
        x: 393,
        y: 134,
        dir: 3,
        sprite: 454,
        name: "Worker",
        scope: :shared,
        unique_name: "Worker#ep13bsg2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Worker]")
      |> mes("What!! Wh.. Oh... I... I didn't fall asleep!!")
      |> mes("Let's get back to work... that's right work...")
      |> close()
    else
      ctx |> mes("[Worker]") |> mes("Ns ad jai osd") |> mes("Rt odj as jo dp as") |> close()
    end
  end
end
