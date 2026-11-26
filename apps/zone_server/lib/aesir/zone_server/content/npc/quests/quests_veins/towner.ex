defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Towner do
  @moduledoc """
  A town resident talks about the local geologist.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 159,
        y: 171,
        dir: 3,
        sprite: 945,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#vol"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("The small office on the")
    |> mes("2nd floor of this weapon")
    |> mes("shop is occupied by a")
    |> mes("geologist. At least, he's")
    |> mes("supposed to be one...")
    |> next()
    |> mes("[Towner]")
    |> mes("The guy might be a quack:")
    |> mes("all he does is drink and")
    |> mes("flirt with skanky women")
    |> mes("all day. I thought scholars")
    |> mes("are supposed to read and study")
    |> mes("and discover things, you know?")
    |> close()
  end
end
