defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Jay do
  @moduledoc """
  Describes Jay's loneliness while eating dinner without his parents.

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
        x: 130,
        y: 41,
        dir: 5,
        sprite: 706,
        name: "Jay",
        scope: :shared,
        unique_name: "Jay#li_house"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Jay]")
    |> mes("My mommy and daddy")
    |> mes("always come home late.")
    |> mes("So I eat dinner alone.")
    |> mes("All by myself. Everyday.")
    |> next()
    |> mes("[Jay]")
    |> mes("Food doesn't taste as")
    |> mes("good when you're not")
    |> mes("eating with anybody.")
    |> mes("Maybe I'm just lonely.")
    |> close()
  end
end
