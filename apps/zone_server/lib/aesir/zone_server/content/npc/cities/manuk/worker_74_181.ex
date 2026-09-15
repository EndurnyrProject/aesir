defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Worker74181 do
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
        x: 74,
        y: 181,
        dir: 3,
        sprite: 454,
        name: "Worker",
        scope: :shared,
        unique_name: "Worker#ep13bs2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx |> mes("[Worker]") |> mes("Chef Cook, how many plates should I put down?") |> close()
    else
      ctx |> mes("[Tee]") |> mes("We pishd bugs ouwwe iro ") |> close()
    end
  end
end
