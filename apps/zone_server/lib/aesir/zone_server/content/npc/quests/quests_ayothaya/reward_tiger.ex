defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.RewardTiger do
  @moduledoc """
  The remains of Boonthom’s comrade in the Ayothaya dungeon.

  ## Behavior

  - Gives an Old Blue Box and advances the quest when the player carries the holy thread.

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
        map: "ayo_dun02",
        x: 268,
        y: 108,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #reward_tiger"
      }
    ]

  @holy_thread 7287
  @old_blue_box 603

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :ayodunquest, 0) == 11 and count_item(ctx, @holy_thread) > 0 do
      ctx
      |> mes(
        "^3355FFYou find half of the skeletal remains of a person sticking out from the ground. It seems to be the remains of Boonthom's comrade.^000000"
      )
      |> next()
      |> mes("^3355FFYou find a piece of paper beside the skeleton, as well as a box.^000000")
      |> next()
      |> mes(
        "^3355FFYou read what is written on the old sheet of paper. The letters have faded with age, and it is difficult to read.^000000"
      )
      |> next()
      |> mes("[Old Letter]")
      |> mes("^333333Dear, Boonthom,")
      |> mes(
        "I was a fool. There is 'Sa-mhing Tig'...One who ....my remains... Please take...to Boonthom..."
      )
      |> next()
      |> mes("^3355FFYou pick")
      |> mes("up the box.^000000")
      |> set_char_var(:ayodunquest, 12)
      |> give_item(@old_blue_box, 1)
      |> close()
    else
      ctx
    end
  end
end
