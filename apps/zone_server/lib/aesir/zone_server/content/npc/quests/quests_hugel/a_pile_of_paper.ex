defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.APileOfPaper do
  @moduledoc """
  Holds research documents for the rebellion quest.

  ## Behavior

  - Gives the documents and alerts the guards at the appropriate quest stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
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
        map: "lhz_in01",
        x: 214,
        y: 129,
        dir: 0,
        sprite: 111,
        name: "A Pile of Paper",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_tre, 0) == 52 do
      ctx
      |> mes("- You found a pile of paper that was tied up with a thick ribbon.")
      |> mes("On the very top paper, a period and a title saying 'Report of the **th Research'")
      |> mes("were written.")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Good, I must take this with me.")
      |> set_char_var(:hg_tre, 53)
      |> give_item(7342, 1)
      |> donpcevent("HuMSpawner::OnMonster")
      |> close()
    else
      ctx
    end
  end
end
