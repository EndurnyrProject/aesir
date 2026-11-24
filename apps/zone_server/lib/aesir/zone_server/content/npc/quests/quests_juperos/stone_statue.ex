defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.StoneStatue do
  @moduledoc """
  Describes a stone statue in the Juperos ruins.

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
        x: 123,
        y: 92,
        dir: 4,
        sprite: 844,
        name: "Stone Statue",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(get_char_var(ctx, :yuno_hist, 0)) do
      ctx
      |> mes("^3355FFIt's a stone statue")
      |> mes("that looks exactly like")
      |> mes("the one in the Juno Library.")
      |> mes("However, it has sculptures")
      |> mes("of books instead of real ones.^000000")
      |> next()
      |> mes("^3355FFIt's possible that the")
      |> mes("statue in the Juno Library")
      |> mes("was made after this one.")
      |> mes("But who can be sure?^000000")
      |> close()
    else
      ctx
      |> mes("^3355FFIt's an old")
      |> mes("statue sculpted")
      |> mes("out of stone.^000000")
      |> close()
    end
  end
end
