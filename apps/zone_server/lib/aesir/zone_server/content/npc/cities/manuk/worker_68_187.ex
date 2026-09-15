defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Worker68187 do
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
        x: 68,
        y: 187,
        dir: 0,
        sprite: 454,
        name: "Worker",
        scope: :shared,
        unique_name: "Worker#ep13bs1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Worker]")
      |> mes("Hmm, it smells delicious.")
      |> mes("It should be time to turn it around now.")
      |> next()
      |> mes("[Worker]")
      |> mes("Hardrock Mammoth steak should be eaten slightly raw!")
      |> close()
    else
      ctx
      |> mes("[Tee]")
      |> mes("As woue dpi sha we")
      |> mes("Two psie bu le")
      |> next()
      |> mes("[Tee]")
      |> mes("Tr sdou powee wwee ")
      |> close()
    end
  end
end
