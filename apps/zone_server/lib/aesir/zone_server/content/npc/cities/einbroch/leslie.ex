defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Leslie do
  @moduledoc """
  Complains about Einbroch's smog while visiting from Einbech.

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
        map: "einbroch",
        x: 259,
        y: 326,
        dir: 3,
        sprite: 846,
        name: "Leslie",
        scope: :shared,
        unique_name: "Leslie#ein_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Leslie]")
    |> mes("^666666*Cough cough!*^000000")
    |> mes("Laaaand sakes!")
    |> next()
    |> mes("[Leslie]")
    |> mes("An old woman like me")
    |> mes("can't breathe this air! How")
    |> mes("do people even live in all this")
    |> mes("smog? Sure, the air in Einbech")
    |> mes("isn't pristine, but the air here in Einbroch is much worse! ^333333*Cough~!*^000000")
    |> next()
    |> mes("[Leslie]")
    |> mes("I hate coming here")
    |> mes("sometimes! The air is")
    |> mes("totally polluted and this")
    |> mes("city is full of stuck up")
    |> mes("pricks! But they sell stuff")
    |> mes("here I can't buy back home...")
    |> close()
  end
end
