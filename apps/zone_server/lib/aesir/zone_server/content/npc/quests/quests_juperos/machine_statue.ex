defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.MachineStatue do
  @moduledoc """
  Describes a humanoid machine statue and its pointing arm.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "juperos_01",
        x: 215,
        y: 127,
        dir: 4,
        sprite: 844,
        name: "Machine Statue",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThis is the bust of a")
    |> mes("humanoid machine with")
    |> mes("a familiar Crest Piece")
    |> mes("carved into the middle.^000000")
    |> next()
    |> mes("^3355FFThe statue's entire")
    |> mes("form is mind boggling,")
    |> mes("but you manage to note")
    |> mes("that its outstretched")
    |> mes("arm points westward.^000000")
    |> close()
  end
end
