defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Worker do
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
        x: 346,
        y: 135,
        dir: 0,
        sprite: 454,
        name: " Worker",
        scope: :shared,
        unique_name: " Worker#ep13bsg1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Worker]")
      |> mes("It is dangerous if the valve is not checked properly every day.")
      |> mes("In fact, there was an incident.")
      |> mes("It gives me the creeps just thinking about it.")
      |> close()
    else
      ctx
      |> mes("[Worker]")
      |> mes("Gs df o aj ud pa")
      |> mes("N sd asw ewt jj ")
      |> mes("Ud aso pda s ")
      |> close()
    end
  end
end
