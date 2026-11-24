defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.HunThai5 do
  @moduledoc """
  The fifth stone slate fragment in the Ayothaya dungeon.

  ## Behavior

  - Advances the dungeon quest and reveals text when found in sequence.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayo_dun01",
        x: 99,
        y: 118,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #hun_thai_5"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ayodunquest, 0) == 7 do
      ctx
      |> set_char_var(:ayodunquest, 8)
      |> mes(
        "^3355FFYou find a piece of a stone slate with letters etched on it. It seems to be the 5th part of the slate.^000000"
      )
      |> next()
      |> mes(
        "^3355FFIt reads '^0000FFYou need more... Holy power... in order to...^3355FF' You are unable to read the rest of the message.^000000"
      )
      |> close()
    else
      ctx
      |> mes(
        "^3355FFYou find a piece of a stone slate with letters etched on it. It seems to be the 5th part of the slate.^000000"
      )
      |> close()
    end
  end
end
