defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.Ekuri do
  @moduledoc """
  Explains how he scavenges scrap metal and ore outside the mine.

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
        x: 130,
        y: 253,
        dir: 1,
        sprite: 848,
        name: "Ekuri",
        scope: :shared,
        unique_name: "Ekuri#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Ekuri]")
    |> mes("Yo-heave-ho!")
    |> mes("Yo-heave-ho~!")
    |> next()
    |> mes("[Ekuri]")
    |> mes("What am I doing here?")
    |> mes("Heck, I'm scared to death")
    |> mes("of entering the mine! But")
    |> mes("I can make a living here at")
    |> mes("the entrance by gathering")
    |> mes("scrap metal! Smart, huh?")
    |> next()
    |> mes("[Ekuri]")
    |> mes("Sometimes, I get lucky")
    |> mes("and score an entire ore!")
    |> mes("Sure, I'm a coward, but")
    |> mes("at least I'm alive. Well,")
    |> mes("for the time being.")
    |> next()
    |> mes("[Ekuri]")
    |> mes("Now you know what")
    |> mes("I'm doing here. So why")
    |> mes("don't you leave me to")
    |> mes("my work? Heave-ho!")
    |> mes("Ores, come to me!")
    |> close()
  end
end
