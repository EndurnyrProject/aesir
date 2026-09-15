defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.ChristopherMichael do
  @moduledoc """
  Shows Christopher Michael resting comfortably in the hotel.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 210,
        y: 189,
        dir: 3,
        sprite: 849,
        name: "Christopher Michael",
        scope: :shared,
        unique_name: "Christopher Michael#zen"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Christopher Michael]")
    |> mes("OoooOoh~")
    |> mes("Soooo comfortable.")
    |> mes("Don't want to wake up.")
    |> mes("Don't want to get up.")
    |> mes("Ever again. OoOoooh...")
    |> close()
  end
end
