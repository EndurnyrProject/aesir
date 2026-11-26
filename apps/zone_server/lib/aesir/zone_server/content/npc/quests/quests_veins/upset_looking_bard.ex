defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.UpsetLookingBard do
  @moduledoc """
  Helps the imprisoned bard Vitre escape.

  ## Behavior

  - Asks for a megaphone and violin, then escapes with the player.

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
        map: "ra_in01",
        x: 50,
        y: 387,
        dir: 4,
        sprite: 51,
        name: "Upset Looking Bard",
        scope: :shared,
        unique_name: "Upset Looking Bard#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :que_sch, 0)

    cond do
      quest < 10 ->
        ctx |> mes("[Vitre]") |> mes(".............") |> close()

      quest == 10 ->
        ask_for_help(ctx)

      quest < 18 ->
        ctx
        |> mes("[Vitre]")
        |> mes("Didn't you bring the")
        |> mes("Megaphone and Violin?")
        |> mes("The longer I sit here,")
        |> mes("the more likely it is")
        |> mes("that they'll kill me!")
        |> close()

      quest == 18 ->
        if count_item(ctx, 7040) > 0 and count_item(ctx, 1901) > 0 do
          ctx
          |> mes("[Vitre]")
          |> mes("You brought me a")
          |> mes("Megaphone and Violin?")
          |> mes("Perfect! Now, step aside")
          |> mes("Can't have you getting hurt.")
          |> next()
          |> mes("...............................")
          |> mes("...............................")
          |> mes("...............................")
          |> next()
          |> mes("^3355FFVitre drew in a deep")
          |> mes("breath, and then smashed")
          |> mes("the steel bars of his cell")
          |> mes("with the Violin. Surprisingly,")
          |> mes("the door swings open with")
          |> mes("a very loud noise.^000000")
          |> next()
          |> mes("[Vitre]")
          |> mes("Heh! That was a little")
          |> mes("harder than I thought,")
          |> mes("but it looks like I'm free~")
          |> mes("Alright, let's get a move on.")
          |> next()
          |> mes("[Jesse]")
          |> mes("What?! What's this noise?!")
          |> next()
          |> enablenpc("Jesse#sch")
          |> mes("[Jesse]")
          |> mes("Hey! How did you")
          |> mes("get out of your cell?!")
          |> mes("Get back in there, NOW!")
          |> next()
          |> mes("[Vitre]")
          |> mes("If you were me, would")
          |> mes("you go back in your cell")
          |> mes("just because someone's")
          |> mes("yelling at you? Forget it~")
          |> next()
          |> mes("^3355FFVitre raised the Megaphone")
          |> mes("to his mouth, and drew in")
          |> mes("another deep breath.^000000")
          |> next()
          |> mes("[Vitre]")
          |> mes("Wah!")
          |> next()
          |> mes("[Jesse]")
          |> mes("Arg...")
          |> mes("Oh Lord...!")
          |> mes("M-my ears...")
          |> next()
          |> mes("[Vitre]")
          |> mes("Heh! I love it when")
          |> mes("a plan comes together~")
          |> mes("Let's get out of here!")
          |> next()
          |> delitem(1901, 1)
          |> delitem(7040, 1)
          |> set_char_var(:que_sch, 19)
          |> close2()
          |> disablenpc("Jesse#sch")
          |> warp("morocc", 294, 153)
        else
          ctx
          |> mes("[Vitre]")
          |> mes("Didn't you bring")
          |> mes("a Megaphone and")
          |> mes("a Violin? Please")
          |> mes("hurry, I don't have")
          |> mes("much time left!")
          |> close()
        end

      true ->
        ctx
        |> mes("[Vitre]")
        |> mes("Heh! I love it when")
        |> mes("a plan comes together~")
        |> mes("Let's get out of here!")
        |> close2()
        |> warp("morocc", 294, 153)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_for_help(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Vitre]")
      |> mes("...............................")
      |> mes("...............................")
      |> mes("...............................")
      |> mes("Damn, what should I do?")
      |> next()
      |> select(["Excuse me..."])

    {ctx, choice} =
      ctx
      |> mes("[Vitre]")
      |> mes("Hm? I'm Vitre Bizlita.")
      |> mes("As you can see, I'm not in")
      |> mes("any real position to help")
      |> mes("you. Still, did you want")
      |> mes("to ask me something?")
      |> next()
      |> select(["Nothing.", "I'm here on behalf of Mr. Lasda."])

    case choice do
      1 ->
        ctx
        |> mes("[Vitre]")
        |> mes("Well...")
        |> mes("It's nice to")
        |> mes("receive visitors.")
        |> mes("Jail can be lonely....")
        |> close()

      2 ->
        ctx
        |> mes("[Vitre]")
        |> mes("Oh, good. Lasda finally")
        |> mes("got my letter, eh? I don't")
        |> mes("know what the hell's going")
        |> mes("on. I mean, all I remember")
        |> mes("is that these strange men")
        |> mes("came and brought me here.")
        |> next()
        |> mes("[Vitre]")
        |> mes("I... I don't think")
        |> mes("they'll let me out")
        |> mes("of here. I mean, they")
        |> mes("jailed me and there's no")
        |> mes("proof I did anything wrong.")
        |> next()
        |> mes("[Vitre]")
        |> mes("My life is in danger as")
        |> mes("long as I'm here, so I have")
        |> mes("to get out as soon as I can.")
        |> mes("Luckily, I figured out that")
        |> mes("I can open these doors if")
        |> mes("I just had 2 things.")
        |> next()
        |> mes("[Vitre]")
        |> mes("I just need a ^FF0000Megaphone^000000")
        |> mes("and a ^FF0000Violin^000000. Luckily, they're")
        |> mes("pretty mundane objects, so no")
        |> mes("one would suspect anything if")
        |> mes("you brought them here. Um...")
        |> mes("You will help me, won't you?")
        |> next()
        |> mes("[Vitre]")
        |> mes("I understand if you have any")
        |> mes("doubts about my innocence.")
        |> mes("But think about it: wouldn't")
        |> mes("you want to see what I do")
        |> mes("with a Megaphone and Violin?")
        |> mes("Sounds pretty cool, huh?")
        |> next()
        |> mes("^3355FFYou can hear someone")
        |> mes("mumbling from the cell")
        |> mes("next to Vitre's.^000000")
        |> next()
        |> mes("[????]")
        |> mes("I wonder how the lady")
        |> mes("in the Dancer Job Change")
        |> mes("place is doing by now...")
        |> set_char_var(:que_sch, 11)
        |> close()

      _ ->
        ctx
    end
  end
end
