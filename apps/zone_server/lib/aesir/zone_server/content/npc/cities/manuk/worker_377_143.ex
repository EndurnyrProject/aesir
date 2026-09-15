defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Worker377143 do
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
        x: 377,
        y: 143,
        dir: 5,
        sprite: 454,
        name: "Worker",
        scope: :shared,
        unique_name: "Worker#ep13bsg3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Worker]")
      |> mes("Hmm... It's working just fine... No problems at all...")
      |> close()
    else
      ctx |> mes("[Worker]") |> mes("Mou ii ros oa d d ") |> close()
    end
  end
end
