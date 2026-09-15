defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.YoungVillager do
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
        map: "manuk",
        x: 251,
        y: 180,
        dir: 5,
        sprite: 454,
        name: "Young Villager",
        scope: :shared,
        unique_name: "Young Villager#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Young Villager]")
      |> mes("It's past the time of our date, why isn't she here yet!!?")
      |> close()
    else
      ctx |> mes("[Asd]") |> mes("Ywo di pi butfs oui Afbsu ") |> close()
    end
  end
end
