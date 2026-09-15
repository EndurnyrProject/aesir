defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.HousemaidBrenda do
  @moduledoc """
  Shows Brenda carefully dusting an extremely valuable vase.

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
        map: "lhz_in03",
        x: 124,
        y: 117,
        dir: 1,
        sprite: 74,
        name: "Housemaid Brenda",
        scope: :shared,
        unique_name: "Housemaid Brenda#li"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Housemaid Brenda]")
    |> mes("I better dust extra")
    |> mes("gently around this vase.")
    |> mes("It's worth ten million zeny")
    |> mes("and if it were to-- No. No!")
    |> mes("I'm not even going to think it!")
    |> close()
  end
end
