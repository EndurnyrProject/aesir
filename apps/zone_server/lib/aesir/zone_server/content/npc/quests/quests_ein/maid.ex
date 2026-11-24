defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Maid do
  @moduledoc """
  The maid answers questions during the murder quest.

  ## Behavior

  - Advances the murder investigation when asked about ore.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 32,
        y: 133,
        dir: 7,
        sprite: 850,
        name: "Maid",
        scope: :shared,
        unique_name: "Maid#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :Shinokas_Quest, 0) == 4 do
      ctx
      |> mes("[Maid]")
      |> mes("Did you ask me")
      |> mes("if I saw some kind")
      |> mes("of ore around here?")
      |> mes("That's strange...")
      |> next()
      |> mes("[Maid]")
      |> mes("Well, I've been with")
      |> mes("this family for a long")
      |> mes("time. Let me assure you")
      |> mes("that there's no secrets")
      |> mes("from me in this household!")
      |> next()
      |> mes("[Maid]")
      |> mes("I'm sorry, but I don't")
      |> mes("think we have any ores,")
      |> mes("special or otherwise, here")
      |> mes("in the manor. What exactly")
      |> mes("do you need them for?")
      |> set_char_var(:Shinokas_Quest, 5)
      |> close()
    else
      ctx
      |> mes("[Maid]")
      |> mes("There's no end")
      |> mes("to all these plates")
      |> mes("I have to clean...!")
      |> close()
    end
  end
end
