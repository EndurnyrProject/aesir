defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.Girl do
  @moduledoc """
  A grieving girl laments the state of the world.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "que_job01",
        x: 70,
        y: 84,
        dir: 1,
        sprite: 882,
        name: "Girl",
        scope: :shared,
        unique_name: "Girl#moc_ex002"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Girl]")
    |> mes("Oh, the world.. the world is doomed..")
    |> mes("-sobbing-")
    |> mes("Nothing seems to be working now..")
    |> emotion(:cry)
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("....Tsk..tsk...")
    |> mes("Good heavens.. I can't believe this young girl's drinking with sadness....")
    |> close()
  end
end
