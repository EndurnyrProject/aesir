defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Teinz do
  @moduledoc """
  Boasts that he will perform any mining work for enough zeny.

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
        x: 113,
        y: 211,
        dir: 3,
        sprite: 851,
        name: "Teinz",
        scope: :shared,
        unique_name: "Teinz#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Teinz]")
    |> mes("If you just pay me money,")
    |> mes("I'll be your slave! There's")
    |> mes("nothing I won't do! Anything")
    |> mes("is fair game. Hell, I'll get buck naked if you pay me enough.")
    |> next()
    |> mes("[Teinz]")
    |> mes("If you pay me what I'm")
    |> mes("worth, I'll work hard at")
    |> mes("any task you set me to.")
    |> mes("Sure, mining's rough, but")
    |> mes("as long as the zeny's coming")
    |> mes("in, I'm happy. Heh heh heh~")
    |> close()
  end
end
