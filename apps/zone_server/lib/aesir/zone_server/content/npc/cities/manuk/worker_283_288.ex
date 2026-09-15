defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Worker283288 do
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
        x: 283,
        y: 288,
        dir: 3,
        sprite: 454,
        name: "Worker",
        scope: :shared,
        unique_name: "Worker#ep13bsg6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Worker]")
      |> mes("It is fortunate to have lots of fine quality Bradium today.")
      |> next()
      |> mes("[Worker]")
      |> mes("This is all that is left for us.")
      |> close()
    else
      ctx
      |> mes("[Worker]")
      |> mes("Qw eI hs pado as d p ")
      |> next()
      |> mes("[Worker]")
      |> mes("Too fn ish d fd")
      |> close()
    end
  end
end
