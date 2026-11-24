defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.HamerunRatHunter do
  @moduledoc """
  Shows a book that the player cannot reach.

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
        map: "yuno_in04",
        x: 111,
        y: 108,
        dir: 1,
        sprite: 111,
        name: "Hamerun, Rat Hunter",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I can't...")
    |> mes("reach it...!")
    |> close()
  end
end
