defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.Hander do
  @moduledoc """
  Complains about Einbech’s dangerous working conditions and exploitation by Einbroch.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 129,
        y: 234,
        dir: 5,
        sprite: 848,
        name: "Hander",
        scope: :shared,
        unique_name: "Hander#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hander]")
    |> mes("Those Einbroch bastards!")
    |> mes("Living off the resources we")
    |> mes("dig up while we keep working")
    |> mes("for them like suckers! Damn!")
    |> next()
    |> mes("[Hander]")
    |> mes("Everyday, we risk our")
    |> mes("freakin' lives just so we")
    |> mes("can make a living! Why don't")
    |> mes("the elders do something about")
    |> mes("this, like raise our ore prices?")
    |> next()
    |> mes("[Hander]")
    |> mes("The work schedule's")
    |> mes("unreasonable, Cavitar's")
    |> mes("wife was attacked by a mine")
    |> mes("creature, the hospital's too")
    |> mes("far away and we don't have")
    |> mes("any food to eat! Why...?!")
    |> close()
  end
end
