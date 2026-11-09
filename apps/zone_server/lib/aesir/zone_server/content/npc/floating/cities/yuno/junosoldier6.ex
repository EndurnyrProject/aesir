defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Yuno.Junosoldier6 do
  @moduledoc """
  Juno soldier who talks about the Sage-only Dagger of Counter.

  ## Behavior

  - Explains that the dagger raises critical chance and is limited to Sages.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf
    - massdriller
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/yuno.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 334,
        y: 182,
        dir: 4,
        sprite: 852,
        name: "Juno Soldier",
        scope: :renewal,
        unique_name: "Juno Soldier#6juno"
      },
      %{
        map: "yuno",
        x: 334,
        y: 182,
        dir: 4,
        sprite: 105,
        name: "Juno Soldier",
        scope: :pre_renewal,
        unique_name: "Juno Soldier#6juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Juno Soldier]")
    |> mes("Welcome to Juno, the city of noble-mindedness.")
    |> next()
    |> mes("[Juno Soldier]")
    |> mes("Among the Sage's weapons, there is a 'Dagger of Counter.'")
    |> next()
    |> mes("[Juno Soldier]")
    |> mes(
      "Its use is limited to the Sage class, and it increases the chance of inflicting critical attacks. So, for Sages, that dagger can be very useful, as well as make them look stylish in battle."
    )
    |> close()
  end
end
