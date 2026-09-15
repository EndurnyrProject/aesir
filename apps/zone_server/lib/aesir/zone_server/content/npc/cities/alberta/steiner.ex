defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.Steiner do
  @moduledoc """
  Shares a merchant scheme involving magic-resistant armor.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 53, y: 39, dir: 0, sprite: 100, name: "Steiner", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Steiner]")
    |> mes("Oh...!")
    |> mes("Welcome to Alberta,")
    |> mes("young adventurer!")
    |> next()
    |> mes("[Steiner]")
    |> mes(
      "Pardon me if I seem distracted. I'm milling about, trying to make a plan. You see, I hear that there is a store in Geffen that sells armor that is resistant to magic."
    )
    |> next()
    |> mes("[Steiner]")
    |> mes("If I buy a lot of them in bulk, and then resell them here for a higher price...")
    |> close()
  end
end
