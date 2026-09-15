defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Khowropher do
  @moduledoc """
  Laments Einbroch's polluted air and its effect on his health.

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
        x: 232,
        y: 255,
        dir: 5,
        sprite: 847,
        name: "Khowropher",
        scope: :shared,
        unique_name: "Khowropher#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Khowropher]")
    |> mes("^666666*Cough cough*^000000")
    |> mes("Jiminy! The air here")
    |> mes("is so thick and grimy!")
    |> mes("And it's worse for us old")
    |> mes("people with breathing")
    |> mes("problems! ^333333*Haaack!*^000000")
    |> next()
    |> mes("[Khowropher]")
    |> mes("I don't care if they keep")
    |> mes("building more and more")
    |> mes("factories and homes in this")
    |> mes("town. Still, I'd like to spend")
    |> mes("the rest of my life somewhere")
    |> mes("quiet and with clean air...")
    |> next()
    |> mes("[Khowropher]")
    |> mes("Then again, Einbroch is my")
    |> mes("hometown and I can't just up")
    |> mes("and leave. I suppose it's my")
    |> mes("fate to suffer from this foul air until the day I die. ^666666*Sigh...*^000000")
    |> close()
  end
end
