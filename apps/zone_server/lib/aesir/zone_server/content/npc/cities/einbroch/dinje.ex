defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Dinje do
  @moduledoc """
  Complains about supporting her exhausted husband through factory work.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 87,
        y: 237,
        dir: 5,
        sprite: 850,
        name: "Dinje",
        scope: :shared,
        unique_name: "Dinje#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Dinje]")
    |> mes("Do you know why a woman")
    |> mes("like me has to work in this")
    |> mes("factory? I'll tell you why... ")
    |> next()
    |> mes("[Dinje]")
    |> mes("My lazy husband, Gesin,")
    |> mes("is just lying there on the")
    |> mes("ground! So I have to work")
    |> mes("in order to support us!")
    |> next()
    |> mes("[Dinje]")
    |> mes("We can't rest for even")
    |> mes("a second if we want to save")
    |> mes("enough money to become")
    |> mes("wealthy and powerful some")
    |> mes("day. Don't you understand?")
    |> next()
    |> mes("[Dinje]")
    |> mes("Well, my husband obviously")
    |> mes("doesn't! How can he not know")
    |> mes("how the real world works?!")
    |> mes("Hey, kick his ass for me if")
    |> mes("he doesn't wake up soon!")
    |> close()
  end
end
