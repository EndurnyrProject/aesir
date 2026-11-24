defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.StrangeDeadBody do
  @moduledoc """
  A corpse in the Kunlun dungeon that holds the thief's last message for the Broken Sword quest.

  ## Behavior

  - Before the chief rewards the thief's trail, it is just a decomposing corpse.
  - While the player hunts for the sword, offers a blood-written note hinting that the sword
    was broken into pieces and separated; reading it changes no quest state.
  - If the player turned down the chief or the hungover man, it is a rotting corpse to pass by;
    later in the quest, a chewed-up skeleton.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_dun03",
        x: 62,
        y: 222,
        dir: 0,
        sprite: 111,
        name: "Strange dead body",
        scope: :shared,
        unique_name: "Strange dead body#gnbs"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :b_sword, 0) do
      stage when stage < 7 ->
        ctx
        |> mes("Here's a decomposing corpse.")
        |> mes("It seems like monsters devoured it.")
        |> close()

      stage when stage < 11 ->
        offers_the_message(ctx)

      stage when stage in [11, 12] ->
        ctx
        |> mes("^3355FFIt's a rotting human corpse...")
        |> mes("I should just pass by.^000000")
        |> close()

      _ ->
        ctx
        |> mes("^3355FFA skeleton chewed up by")
        |> mes("monsters...I feel sorry for")
        |> mes("him, but start getting this")
        |> mes("really creepy feeling after staring at it for a while.^000000")
        |> close()
    end
  end

  defp offers_the_message(ctx) do
    {ctx, choice} =
      ctx
      |> mes("There's a written message between the bones of the corpse.")
      |> mes("of the corpse.")
      |> mes("Take a look?")
      |> next()
      |> select(["Yes.", "Eew, no!"])

    if choice == 1, do: reads_the_message(ctx), else: refuses(ctx)
  end

  defp reads_the_message(ctx) do
    ctx
    |> mes("^3355FFThe paper is old and fading,")
    |> mes("but there are words on it.")
    |> mes("It's written in blood.")
    |> mes("The letters are faded and it's almost impossible to read...^000000 ")
    |> next()
    |> mes("^FF0000Damn I can't.. believe.. failed..")
    |> mes("Sayum... I should've..")
    |> mes("watchout.. ehhh.. but.. break")
    |> mes("..pieces.. and separate..")
    |> mes("I.. with")
    |> mes("this...^000000")
    |> next()
    |> mes("^3355FFThe rest was indecipherable...")
    |> mes("He probably couldn't take it any longer...^000000")
    |> close()
  end

  defp refuses(ctx) do
    ctx
    |> mes("[ ^6699FF#{char_name(ctx, 0)}^000000 ]")
    |> mes("Eew, no!")
    |> mes(" ")
    |> mes("Yucky yucky YUCKY!")
    |> next()
    |> mes("^3355FFYou feel like there's something important here...")
    |> mes("But the rotting carcass has a")
    |> mes("foul odor that makes you feel nauseated.^000000")
    |> close()
  end
end
