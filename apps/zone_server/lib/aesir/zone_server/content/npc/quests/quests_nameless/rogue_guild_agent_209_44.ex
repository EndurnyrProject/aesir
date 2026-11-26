defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.RogueGuildAgent20944 do
  @moduledoc """
  The Payon Rogue Guild agent investigates the poisoned well with the player.

  ## Behavior

  - Coordinates the investigation and requests herbs and alcohol.
  - Sends the player onward with a report when the investigation is complete.

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
      %{
        map: "payon",
        x: 209,
        y: 44,
        dir: 5,
        sprite: 828,
        name: "Rogue Guild Agent",
        scope: :shared,
        unique_name: "Rogue Guild Agent#nd2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rumour_nd, 0) < 3 ->
        ctx = ctx |> mes("[Agent]") |> mes("What? You want somethin'?") |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("?????????????????")
        |> next()
        |> mes("[Agent]")
        |> mes("Heh. Thought so.")
        |> close()

      get_char_var(ctx, :rumour_nd, 0) > 2 and get_char_var(ctx, :rumour_nd, 0) < 6 ->
        ctx
        |> mes("[Agent]")
        |> mes("What's up? I got")
        |> mes("my hands full, so")
        |> mes("make it quick.")
        |> next()
        |> mes("[Agent]")
        |> mes("Nothin', huh?")
        |> mes("Guess you should")
        |> mes("be talking a Rogue")
        |> mes("agent in one of the")
        |> mes("other towns.")
        |> emotion(:anger)
        |> close()

      get_char_var(ctx, :rumour_nd, 0) == 6 ->
        {ctx, _} =
          ctx
          |> mes("[Agent]")
          |> mes("Hey. What are you")
          |> mes("doin', just loitering")
          |> mes("around here? You lookin'")
          |> mes("for somebody? Huh?")
          |> next()
          |> select(["I'm here to help a Rogue Agent!"])

        ctx = ctx |> mes("[Agent]") |> mes("Oh, yeah?") |> next()

        ctx =
          cond do
            Rathena.job_id(base_job(ctx)) == Rathena.job_id(:rogue) ->
              ctx
              |> mes("[Agent]")
              |> mes("Heya guy. Always good")
              |> mes("to see a fellow Rogue.")
              |> mes("You know I'm just messin'")
              |> mes("around with you, right?")

            true ->
              ctx
              |> mes("[Agent]")
              |> mes("I heard o' you guys,")
              |> mes("Rogues workin' undercover.")
              |> mes("Don't try to fool me: under")
              |> mes("those clothes, you are one")
              |> mes("hundred percent Rogue. Heh!")
          end

        ctx =
          ctx
          |> next()
          |> mes("^3355FFYou deliver the")
          |> mes("folded note to him.^000000")
          |> next()
          |> mes("[Agent]")
          |> mes("Awwww, man!")
          |> emotion(:huk)
          |> next()
          |> mes("[Agent]")
          |> mes("I keep telling that")
          |> mes("guy to just send me")
          |> mes("pictures! I've told him")
          |> mes("so many times that I've")
          |> mes("got trouble reading!")
          |> mes("That guy's a moron!")
          |> next()
          |> mes("[Agent]")
          |> mes("Uh...")
          |> mes("You mind reading")
          |> mes("this note to me?")
          |> set_char_var(:rumour_nd, 7)
          |> next()

        read_note(ctx)

      get_char_var(ctx, :rumour_nd, 0) == 7 ->
        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Hey, I asked you")
          |> mes("to read the note,")
          |> mes("not run away! Now...")
          |> mes("What's it say?")
          |> next()

        read_note(ctx)

      get_char_var(ctx, :rumour_nd, 0) == 8 ->
        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Good, you're back.")
          |> mes("We got a pretty big")
          |> mes("job to take care of.")
          |> mes("Lives are at stake,")
          |> mes("all that jazz. Ready?")
          |> next()

        cond do
          get_char_var(ctx, :zdan_edq, 0) > 12 ->
            ctx
            |> mes("[Agent]")
            |> mes("The Z Gang poisoned")
            |> mes("one of the water wells")
            |> mes("here in Payon. All the")
            |> mes("water's black now. We gotta")
            |> mes("use Red Herbs to counter")
            |> mes("that poison, okay?")
            |> next()
            |> mes("[Agent]")
            |> mes("So remember to")
            |> mes("collect some ^FF0000Red Herbs^000000.")
            |> mes("Don't forget: ^FF0000Red herbs^000000.")
            |> next()
            |> mes("[Agent]")
            |> mes("Wait, that doesn't")
            |> mes("sound right. Did I say")
            |> mes("Red Herbs? I'm sorry,")
            |> mes("I meant to say ^0000FFGreen")
            |> mes("Herbs^000000. Bring me ^0000FF1 Green")
            |> mes("Herb^000000, okay? *Phew~*")
            |> set_char_var(:rumour_nd, 9)
            |> close()

          true ->
            ctx
            |> mes("[Agent]")
            |> mes("Someone's poisoned")
            |> mes("Payon's well water...")
            |> mes("It's all black and")
            |> mes("deadly now. I want you")
            |> mes("to bring me a ^FF0000Red Herb^000000")
            |> mes("so that we can fix this!")
            |> set_char_var(:rumour_nd, 10)
            |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 9 ->
        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Hey, you're back!")
          |> mes("You're much quicker")
          |> mes("that I thought you'd be~")
          |> next()

        cond do
          count_item(ctx, 511) > 0 ->
            ctx
            |> delitem(511, 1)
            |> set_char_var(:rumour_nd, 11)
            |> mes("[Agent]")
            |> mes("Alright, it's gonna take")
            |> mes("a while to neutralize all")
            |> mes("this poison, but I think")
            |> mes("we did it. Hey, gimmie")
            |> mes("some time to draw a report,")
            |> mes("and then come back later, 'kay?")
            |> close()

          true ->
            ctx
            |> mes("[Agent]")
            |> mes("Err?")
            |> mes("Where's that")
            |> mes("Green Herb?")
            |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 10 ->
        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Hey, you're back!")
          |> mes("You're much quicker")
          |> mes("that I thought you'd be~")
          |> next()

        cond do
          count_item(ctx, 507) > 0 ->
            cond do
              count_item(ctx, 511) > 0 ->
                ctx
                |> mes("[Agent]")
                |> mes("Ah, a Green Herb!")
                |> mes("Is that what I told")
                |> mes("you to bring? 'Cause")
                |> mes("I'm sure this is the")
                |> mes("right one. Absolutely~")
                |> next()
                |> mes("[Agent]")
                |> mes("Alright, it's gonna take")
                |> mes("a while to neutralize all")
                |> mes("this poison, but I think")
                |> mes("we did it. Hey, gimmie")
                |> mes("some time to draw a report,")
                |> mes("and then come back later, 'kay?")
                |> delitem(511, 1)
                |> set_char_var(:rumour_nd, 11)
                |> close()

              true ->
                {ctx, _} =
                  ctx
                  |> mes("[Agent]")
                  |> mes("Hey, what are you")
                  |> mes("doin' with the Red Herb?")
                  |> next()
                  |> select(["You said a Red Herb..."])

                ctx
                |> mes("[Agent]")
                |> mes("Oh, what?! Huh...")
                |> mes("I guess I did. Eh, no")
                |> mes("biggie. Hey, bring me")
                |> mes("a Green Herb, will you?")
                |> mes("That's the one I wanted.")
                |> set_char_var(:rumour_nd, 9)
                |> close()
            end

          count_item(ctx, 511) > 0 ->
            ctx
            |> mes("[Agent]")
            |> mes("Alright, it's gonna take")
            |> mes("a while to neutralize all")
            |> mes("this poison, but I think")
            |> mes("we did it. Hey, gimmie")
            |> mes("some time to draw a report,")
            |> mes("and then come back later, 'kay?")
            |> delitem(511, 1)
            |> set_char_var(:rumour_nd, 11)
            |> close()

          true ->
            ctx
            |> mes("[Agent]")
            |> mes("Err?")
            |> mes("Where's that")
            |> mes("Green Herb?")
            |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 11 ->
        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Hey, you know what?")
          |> mes("The well water is still")
          |> mes("black. That means...")
          |> mes("If the herb we used is")
          |> mes("good... Then it's just")
          |> mes("dyed black to scare people.")
          |> next()
          |> mes("[Agent]")
          |> mes("So to clean up the")
          |> mes("water, we gotta use")
          |> mes("a Counteragent, right?")
          |> mes("Will you help me out?")
          |> mes("I got a Karvodailnirol...")
          |> next()
          |> mes("[Agent]")
          |> mes("So if you bring me")
          |> mes("^0000FF1 Alcohol^000000, we should")
          |> mes("be totally good to")
          |> mes("make a Counteragent.")
          |> next()

        cond do
          Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist) ->
            {ctx, _} = select(ctx, ["Wait, Karvodailnirol?!"])

            ctx =
              ctx
              |> mes("[Agent]")
              |> mes("Yeah. Karvodailnirol.")
              |> mes("What about it?")
              |> next()

            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("You need Detrimindexta")
            |> mes("to make a Counteragent,")
            |> mes("not Karvodailnirol.")
            |> next()
            |> mes("[Agent]")
            |> mes("Oh, really? Heh!")
            |> mes("You're a lifesaver!")
            |> mes("Detrimindexta, huh?")
            |> next()
            |> emotion(:kik)
            |> mes("[Agent]")
            |> mes("Don't worry, I got")
            |> mes("that one too! All you")
            |> mes("gotta do is bring Alcohol~")
            |> set_char_var(:rumour_nd, 12)
            |> close()

          true ->
            ctx
            |> mes("[Agent]")
            |> mes("Alright, just bring")
            |> mes("me an Alcohol, and")
            |> mes("I'll take care of the rest.")
            |> set_char_var(:rumour_nd, 13)
            |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 12 ->
        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Everything's ready")
          |> mes("except for the Alcohol.")
          |> mes("Did you bring it?")
          |> next()

        cond do
          count_item(ctx, 970) > 0 ->
            ctx
            |> mes("[Agent]")
            |> mes("Great, now all we")
            |> mes("have to do is wait.")
            |> mes("Nice work, partner.")
            |> delitem(970, 1)
            |> set_char_var(:rumour_nd, 15)
            |> close()

          true ->
            ctx
            |> mes("[Agent]")
            |> mes("You don't have it?")
            |> mes("You didn't drink")
            |> mes("the alcohol, did you?")
            |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 13 ->
        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Everything's ready")
          |> mes("except for the Alcohol.")
          |> mes("Did you bring it?")
          |> next()

        cond do
          count_item(ctx, 970) > 0 ->
            ctx
            |> mes("[Agent]")
            |> mes("Great, now all we")
            |> mes("have to do is wait.")
            |> mes("Nice work, partner.")
            |> delitem(970, 1)
            |> set_char_var(:rumour_nd, 14)
            |> close()

          true ->
            ctx
            |> mes("[Agent]")
            |> mes("You don't have it?")
            |> mes("You didn't drink")
            |> mes("the alcohol, did you?")
            |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 14 ->
        ctx
        |> mes("[Agent]")
        |> mes("Um, I made a mistake")
        |> mes("making the Counteragent...")
        |> mes("I was supposed to use this")
        |> mes("Detrimindexta, not the other")
        |> mes("thing, Karvodailnirol, to")
        |> mes("make the Counteragent.")
        |> next()
        |> mes("[Agent]")
        |> mes("Sorry, they both look")
        |> mes("the same to me. And, well,")
        |> mes("so do all the letters of")
        |> mes("the alphabet. You mind")
        |> mes("trying this out again?")
        |> mes("Just 1 more Alcohol...")
        |> next()
        |> mes("[Agent]")
        |> mes("Hey, I promise!")
        |> mes("I won't screw it up")
        |> mes("this time. We'll")
        |> mes("do this for sure~")
        |> set_char_var(:rumour_nd, 12)
        |> close()

      get_char_var(ctx, :rumour_nd, 0) == 15 ->
        ctx =
          ctx
          |> emotion(:smile)
          |> mes("[Agent]")
          |> mes("Heh heh! Looks like")
          |> mes("we solved the case!")
          |> mes("The water wasn't really")
          |> mes("poisoned... Just colored")
          |> mes("to look suspicious. See?")
          |> mes("Completely safe to drink.")
          |> next()
          |> mes("[Agent]")
          |> mes("Anyway, looks like")
          |> mes("we're done here. You")
          |> mes("mind taking my report over")
          |> mes("to the next Rogue agent?")
          |> next()

        cond do
          Enum.random(1..2) == 1 ->
            ctx
            |> mes("[Agent]")
            |> mes("Make sure to take")
            |> mes("this to the guy in")
            |> mes("Comodo, okay?")
            |> next()
            |> mes("^3355FFYou received a note that")
            |> mes("communicates solely")
            |> mes("through doodles.^000000")
            |> set_char_var(:rumour_nd, 18)
            |> close()

          true ->
            ctx
            |> mes("[Agent]")
            |> mes("Make sure to take")
            |> mes("this to the guy in")
            |> mes("Al De Baran, okay?")
            |> next()
            |> mes("^3355FFYou received a note that")
            |> mes("communicates solely")
            |> mes("through doodles.^000000")
            |> set_char_var(:rumour_nd, 16)
            |> emotion(:smile)
            |> close()
        end

      get_char_var(ctx, :rumour_nd, 0) == 16 ->
        ctx
        |> mes("[Agent]")
        |> mes("Be sure that the")
        |> mes("Rogue agent over")
        |> mes("in Al De Baran gets")
        |> mes("my report, okay?")
        |> close()

      get_char_var(ctx, :rumour_nd, 0) == 17 ->
        ctx
        |> mes("[Agent]")
        |> mes("Huh, the guy in")
        |> mes("Al De Baran wouldn't")
        |> mes("take it? Oh! That's why!")
        |> mes("I meant Comodo! You gotta")
        |> mes("go to Comodo! Heh, my bad~")
        |> set_char_var(:rumour_nd, 18)
        |> close()

      get_char_var(ctx, :rumour_nd, 0) == 18 ->
        ctx
        |> mes("[Agent]")
        |> mes("Be sure that the")
        |> mes("Rogue agent over")
        |> mes("in Comodo gets")
        |> mes("my report, okay?")
        |> close()

      true ->
        ctx
        |> mes("[Agent]")
        |> mes("Hey, partner, how's")
        |> mes("it going? I'm sorry")
        |> mes("if I'm a bit of a hassle")
        |> mes("to work with. I might lack")
        |> mes("book smarts, but I make")
        |> mes("up for it some with my saavy.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp read_note(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Let's see,")
      |> mes("the note says...")
      |> next()
      |> select(["Cooperate with this adventurer.", "......"])

    case choice do
      1 ->
        ctx
        |> mes("[Agent]")
        |> mes("So... We're partners?")
        |> mes("Cool. Nice to meetcha.")
        |> mes("I'm the Payon agent.")
        |> mes("I guess we gotta work")
        |> mes("together from now on.")
        |> set_char_var(:rumour_nd, 8)
        |> close()

      2 ->
        ctx
        |> mes("[Agent]")
        |> mes("You...")
        |> mes("You can't read either?")
        |> next()
        |> mes("[Agent]")
        |> mes("Hahaha! Right on, right on.")
        |> mes("Well, I'm pretty sure they")
        |> mes("sent you to work with me.")
        |> mes("When you're ready to get")
        |> mes("to business, come back")
        |> mes("and we'll talk, okay?")
        |> set_char_var(:rumour_nd, 8)
        |> close()

      _ ->
        ctx
    end
  end
end
