defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Archeologist do
  @moduledoc """
  An archeologist researches the history of the Unlucky Emerald.

  ## Behavior

  - Discusses the jewel and advances the investigation into its former owner.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "yuno_in04", x: 38, y: 48, dir: 3, sprite: 55, name: "Archeologist", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :jewel_nd, 0) < 18 ->
        ctx
        |> mes("[Archeologist]")
        |> mes("There's so much to do!")
        |> mes("How am I going to handle")
        |> mes("all of this research? Don't")
        |> mes("panic, don't panic, just")
        |> mes("one thing at a time!")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 18 ->
        ctx =
          ctx
          |> mes("[Archeologist]")
          |> mes("Oh, I've heard about you")
          |> mes("from that antique appraiser")
          |> mes("in Comodo... You're the one")
          |> mes("that dig up the Unlucky")
          |> mes("Emerald, right? Would")
          |> mes("you mind if I take a look?")
          |> next()

        if count_item(ctx, 7725) > 0 do
          {ctx, choice} =
            ctx
            |> mes("[Archeologist]")
            |> mes("Ah, it's no wonder so")
            |> mes("many people want it.")
            |> mes("This emerald is so huge")
            |> mes("and... It's beautiful! So...")
            |> mes("I'm guessing you needed")
            |> mes("my help with something?")
            |> next()
            |> select(["Ask About the Jewel's Curse", "Show Off Jewel"])

          case choice do
            1 ->
              ctx
              |> emotion(:smile)
              |> mes("[Archeologist]")
              |> mes("The jewel's curse?")
              |> mes("Hah! You believe in that")
              |> mes("old superstition? Oh, so")
              |> mes("you wanted to break the")
              |> mes("jewel's curse? Mmpf. Hahah!")
              |> mes("You're not dead yet, right?")
              |> next()
              |> mes("[Archeologist]")
              |> mes("It's all a load of bunk!")
              |> mes("Only one man died while")
              |> mes("keeping this jewel in his")
              |> mes("possession, that gambler in")
              |> mes("Comodo that used it to pay")
              |> mes("off his gambling debts.")
              |> next()
              |> mes("[Archeologist]")
              |> mes("This jewel happened to be")
              |> mes("lost for a long time, and it")
              |> mes("just reappeared. That's all.")
              |> mes("Lots of myths and legends")
              |> mes("surround extremely valuable")
              |> mes("gems like this one.")
              |> next()
              |> mes("[Archeologist]")
              |> mes("Anyway, there's no curse.")
              |> mes("Believe what you want to,")
              |> mes("but that happens to be my")
              |> mes("professional opinion,")
              |> mes("based on my research.")
              |> set_char_var(:jewel_nd, 19)
              |> close()

            2 ->
              ctx
              |> mes("[Archeologist]")
              |> mes("Wow...")
              |> mes("That jewel sure")
              |> mes("is freakin' huge...")
              |> close()

            _ ->
              ctx
          end
        else
          ctx
          |> mes("[Archeologist]")
          |> mes("You lost the jewel?")
          |> mes("Well, maybe it's not")
          |> mes("all bad. History shows")
          |> mes("that many people were")
          |> mes("ruined by suddenly coming")
          |> mes("upon vast fortunes, you know?")
          |> close()
        end

      get_char_var(ctx, :jewel_nd, 0) == 22 ->
        ctx
        |> mes("[Archeologist]")
        |> mes("The vindictive soul")
        |> mes("of a warrior is just")
        |> mes("drifting around in the")
        |> mes("world of the living?")
        |> mes("I don't think I want to")
        |> mes("believe what you're saying.")
        |> next()
        |> mes("[Archeologist]")
        |> mes("I personally feel that")
        |> mes("old shaman's a fraud, but...")
        |> mes("You should have the freedom")
        |> mes("to decide what you believe.")
        |> mes("But don't let it bother you.")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 23 ->
        ctx
        |> mes("[Archeologist]")
        |> mes("Are you talking about")
        |> mes("ghosts again? Fine. For")
        |> mes("the sake of the argument,")
        |> mes("let's say the jewel actually")
        |> mes("possesses the soul of")
        |> mes("some fallen warrior.")
        |> next()
        |> mes("[Archeologist]")
        |> mes("It's not unfathomable for")
        |> mes("people with huge debts to")
        |> mes("kill themselves, or for")
        |> mes("warriors to perish while")
        |> mes("fighting Cobolds. Still...")
        |> mes("I'll see what I can learn.")
        |> next()
        |> mes("[Archeologist]")
        |> mes("That reminds me...")
        |> mes("I've got some records about")
        |> mes("an adventurer group that died")
        |> mes("in the field west of Geffen")
        |> mes("that you were talking about.")
        |> mes("Let me see if I can find them.")
        |> set_char_var(:jewel_nd, 24)
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 24 ->
        ctx
        |> mes("[Archeologist]")
        |> mes("Ah, you're back! I found")
        |> mes("those records I told you")
        |> mes("about. It's a witness's")
        |> mes("account of what happened")
        |> mes("when those people died")
        |> mes("west of Geffen.")
        |> next()
        |> mes("[Archeologist]")
        |> mes("What's interesting is that")
        |> mes("the warrior you keep talking")
        |> mes("about wasn't killed by Cobolds")
        |> mes("at all, according to what this")
        |> mes("guy wrote. Let's see...")
        |> mes("Ah, it's over here.")
        |> next()
        |> mes("[Archeologist]")
        |> mes("''^666666When the chief and his")
        |> mes("soldiers arrived, the battle")
        |> mes("was over. Dead bodies lay")
        |> mes("everywhere, but there was")
        |> mes("one warrior covered in blood,")
        |> mes("half conscious, but living.^000000''")
        |> next()
        |> mes("[Archeologist]")
        |> mes("Strange, isn't it?")
        |> mes("This is from a journal")
        |> mes("written by a retired soldier")
        |> mes("that lives in Prontera now.")
        |> mes("It might be a good idea to")
        |> mes("see if you can talk to him.")
        |> set_char_var(:jewel_nd, 25)
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 25 ->
        ctx
        |> mes("[Archeologist]")
        |> mes("There's a retired soldier")
        |> mes("that actually witnessed what")
        |> mes("happened in the field west")
        |> mes("of Geffen. You should try")
        |> mes("to find him in Prontera, and")
        |> mes("see what you can learn.")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) > 28 ->
        ctx
        |> mes("[Archeologist]")
        |> mes("Ah, that's... That's")
        |> mes("very profound. That one")
        |> mes("warrior went berserk when")
        |> mes("he realized he was too weak")
        |> mes("to protect his comrades?")
        |> mes("He lost total control...")
        |> next()
        |> mes("[Archeologist]")
        |> mes("I better talk to that")
        |> mes("old soldier and get the")
        |> mes("full story on record.")
        |> mes("It'll be a really good history")
        |> mes("lesson for Swordmen everywhere.")
        |> mes("Thank you for letting me know.")
        |> close()

      true ->
        ctx
        |> mes("[Archeologist]")
        |> mes("I'm so busy! Listen,")
        |> mes("would you mind coming")
        |> mes("back later when I'm not")
        |> mes("so swamped with work?")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
