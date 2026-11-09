defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Rin14454 do
  @moduledoc """
  Rin in the Morocc hideout, who confronts Rayan with the player after the journal and the
  Bloody Crystal of Darkness are recovered, then sends the player to Echinacea with Rayan's
  magic pattern number.

  ## Behavior

  - Refuses the conversation while the player carries too many items.
  - `mao_morocc2` 21 runs the Rayan scene when the player carries both the Morocc Tracing Log
    (6029) and the Bloody Crystal of Darkness (6027): Rayan's confession, the three ways to
    subdue him, Satan Morocc speaking through him, and the loss of both items (step 22).
    Without both items she only asks what the player wants.
  - 22 hands out the Morocc Tracing Log and one of three pattern numbers, drawn at random, and
    advances quest 7030 to 7030 plus the draw (steps 23, 24, 25).
  - 23 to 28 repeat the pattern number for the step, and any other step only says she needs
    to rest.
  - Hides itself on boot: its empty `OnInit` label runs into `OnDisable`.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_job01",
        x: 144,
        y: 54,
        dir: 3,
        sprite: 885,
        name: "Rin",
        scope: :shared,
        unique_name: "Rin#moc_room2_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Rin#moc_room2_2"
  @rayan "Rayan#moc_room2_2"
  @tracing_log 6029
  @dark_crystal 6027
  @patterns ["SDHF92F-SDF", "VWNM94GVWN90", "CM3-TRDFGHE0"]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnEnable", ctx), do: enablenpc(ctx, @npc)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{714, 1}]) == 0 do
      overloaded(ctx)
    else
      at_step(ctx, get_char_var(ctx, :mao_morocc2, 0))
    end
  end

  # Every branch of the reference ends in `close2`, which keeps the script running, so the
  # portrait is cleared on the way out of each of them.
  defp hide_portrait(ctx), do: cutin(ctx, "moc2_rin01", 255)

  defp at_step(ctx, 21), do: with_the_journal(ctx)
  defp at_step(ctx, 22), do: explains_the_pattern(ctx)
  defp at_step(ctx, 23), do: reminder(ctx, Enum.at(@patterns, 0))
  defp at_step(ctx, 24), do: reminder(ctx, Enum.at(@patterns, 1))
  defp at_step(ctx, 25), do: reminder(ctx, Enum.at(@patterns, 2))

  defp at_step(ctx, step) when step > 25 and step < 29 do
    forgotten_pattern(ctx, Enum.at(@patterns, step - 26))
  end

  defp at_step(ctx, _step) do
    ctx
    |> cutin("moc2_rin01", 2)
    |> mes("[Rin]")
    |> mes("Ahhh~ I'm a sick person. I need to rest!")
    |> mes("I don't want to do anything else~")
    |> mes("Hurry up and go, don't bother me~")
    |> close()
    |> hide_portrait()
  end

  defp overloaded(ctx) do
    ctx
    |> mes("- You cannot proceed with the quest when you're carrying too many items with you. -")
    |> close()
  end

  defp with_the_journal(ctx) do
    if count_item(ctx, @tracing_log) > 0 and count_item(ctx, @dark_crystal) > 0 do
      confronts_rayan(ctx)
    else
      ctx
      |> cutin("moc2_rin01", 2)
      |> mes("[Rin]")
      |> mes("What's up?")
      |> mes("I'm kind of busy right now.")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("..I've brought back the journal and something else..")
      |> mes("..Er, sorry. I forgot to bring the journal! I'll be right back.")
      |> close()
      |> hide_portrait()
    end
  end

  defp confronts_rayan(ctx) do
    {ctx, _} =
      ctx
      |> cutin("moc2_rin03", 2)
      |> mes("[Rin]")
      |> mes("Hey, you've come back at just the right time.")
      |> mes("Look at him; this is ridiculous.")
      |> next()
      |> cutin("moc2_dan02", 0)
      |> mes("[Rayan]")
      |> mes("I know what I did is unforgivable, no matter how good my reason might be.")
      |> mes("..But... *Sigh*... It's too late to regret it now, isn't it?")
      |> next()
      |> select(["Who is this?"])

    ctx =
      ctx
      |> cutin("moc2_rin01", 2)
      |> mes("[Rin]")
      |> mes(
        "Don't you know? He's Rayan Moore who dared to release Satan Morocc, deceive everyone, and bring havoc to this world."
      )
      |> mes("And you know what?")
      |> next()
      |> mes("[Rin]")
      |> mes("Not only that, he slaughtered his own comrades without mercy!")
      |> next()
      |> cutin("moc2_dan02", 0)
      |> mes("[Rayan]")
      |> mes("...Waaah!")
      |> mes("..I.. I.. I killed them with my own hands!")
      |> mes("*Sob*..")
      |> mes("I'm.. I'm sorry..")
      |> next()
      |> mes("- Rayan is shivering in fear.")
      |> mes("He still hasn't gotten over the fact that he killed all of his comrades.-")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What is going on?")
      |> mes("He doesn't look like the Rayan I know.")
      |> next()
      |> cutin("moc2_rin03", 2)
      |> mes("[Rin]")
      |> mes(
        "I don't know. This Rayan seems to be a completely different individual than the one we know."
      )
      |> mes("I guess this is what they call Multiple Personality Disorder.")
      |> next()
      |> mes("[Rin]")
      |> mes("This Rayan isn't the Rayan Moore that plotted the conspiracy,")
      |> mes("but another personality hidden inside of him.")
      |> next()
      |> cutin("moc2_rin01", 2)
      |> mes("[Rin]")
      |> mes("Hey, calm down. Why don't you speak slowly?")
      |> next()
      |> cutin("moc2_dan02", 0)
      |> mes("[Rayan]")
      |> mes("..It was me.. I was only going to pretend to break the seal of Satan Morocc...")
      |> mes(
        "Don't you see? I meant for it to just be an act! I was going to throw the town in panic..."
      )
      |> next()
      |> mes("[Rayan]")
      |> mes("..That would be my chance to spread the teachings of Freya, our messiah.")
      |> mes("Then something went wrong...")
      |> next()
      |> cutin("moc2_rin04", 2)
      |> mes("[Rin]")
      |> mes("What?")
      |> mes("Man, how can you be so stupid?!")
      |> mes("*Sigh* Continue.")
      |> next()
      |> cutin("moc2_dan02", 0)
      |> mes("[Rayan]")
      |> mes("I was studying some documents for my plan, and then I found something by accident.")
      |> mes("That was when I became a completely different person.. *Sob*")
      |> next()
      |> mes("[Rayan]")
      |> mes(
        "..My plan.. It was like I wasn't myself anymore. I wanted to release Satan Morocc for real."
      )
      |> mes("I kidnapped children.. Threatened my comrades.")
      |> next()
      |> mes("[Rayan]")
      |> mes("..I held the true ritual to break the seal and release Satan Morocc...")
      |> mes("Wah.. My.. My head hurts.. This.. No, you can't.. Waaah!")
      |> next()
      |> mes("[Rayan]")
      |> mes("..Grr.. You.. You foolish weaklings..")
      |> mes("..I shall kill you.. No... Nooo!")
      |> next()
      |> mes("- Suddenly Rayan started talking nonsense and then pulled his hair out in anguish.")
      |> mes("It seems as if he is trying to resist the evil personality within him. -")
      |> next()
      |> cutin("moc2_dan02", 255)
      |> select(["Smack his head.", "Punch his stomach.", "Slap his face."])

    case choice do
      1 ->
        struck(
          ctx,
          :hit2,
          "- Wanting to stop Rayan from going berserk, you smacked the back of his head with the journal. Rayan staggered and then fell to the ground. Nice job! -"
        )

      2 ->
        struck(
          ctx,
          :hit4,
          "- Wanting to stop Rayan from going berserk, you sucker punched him in the 'ole bread basket. Rayan staggered and then fell to the ground...! -"
        )

      3 ->
        struck(
          ctx,
          :hit1,
          "- Wanting to stop Rayan from going berserk, you slapped his face with the journal. Rayan staggered and then fell onto the ground. Wah! -"
        )

      _ ->
        ctx
    end
  end

  defp struck(ctx, effect, text) do
    ctx
    |> specialeffect(effect, :area, @rayan)
    |> mes(text)
    |> next()
    |> the_crystal_rolls()
  end

  defp the_crystal_rolls(ctx) do
    ctx =
      ctx
      |> mes(
        "- By your sudden violent move, the Bloody Crystal of Darkness flew out of your jacket, and rolled on the ground toward Rayan. -"
      )
      |> next()
      |> cutin("moc2_dan02", 0)
      |> mes("[Rayan]")
      |> mes("Ahh....")
      |> mes("....? Isn't.. Isn't this?!....")
      |> specialeffect(:poison, :area, @rayan)
      |> next()
      |> mes("[Rin]")
      |> mes("Wah! What's going on?")
      |> mes("Why is it suddenly..?!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Is this a time-space phenomenon?!")
      |> mes("Why..? There's no gap here..?")
      |> next()
      |> cutin("moc2_dan01", 1)
      |> mes("[Rayan]")
      |> mes("Haha.. Muhahaha!")
      |> mes("Muhahahahaha!!")
      |> mes("He's come.. My master has arrived!!")
      |> mes("As you command, master. I'm here to serve you!")
      |> next()
      |> mes("[Voice from Rayan]")
      |> mes("^FF0000You insignificant humans!")
      |> mes("I'll be back at full strength,")
      |> mes("and I'll pay you back for locking me in the darkness for hundreds of years!^000000")
      |> next()
      |> cutin("moc2_rin04", 2)
      |> mes("[Rin]")
      |> mes("What... What just happened?")
      |> mes("Are you Rayan? Or are you someone else now?!")
      |> next()
      |> cutin("moc2_dan01", 0)
      |> mes("[Rayan]")
      |> mes("You're too late. My master has already departed!")
      |> mes("I'm his loyal servant.")
      |> mes("You're too foolish to understand his great will.")
      |> next()
      |> mes("[Rayan]")
      |> mes("Haha... Muhahaha!")
      |> mes("He's calling me!")
      |> mes("He needs me now!")
      |> next()
      |> mes("[Rayan]")
      |> mes("You're Rin, right?")
      |> mes("This is the last time you'll ever see me.")
      |> mes("Haha... Muhahahahaha!!")
      |> specialeffect(:entry, :area, @rayan)
      |> donpcevent("#{@rayan}::OnDisable")
      |> next()
      |> cutin("moc2_rin03", 2)
      |> mes("[Rin]")
      |> mes("............")
      |> mes("....Huh...?")
      |> mes("What just happened?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("...I don't know...")
    |> mes("...I think he's gone...?")
    |> delitem(@tracing_log, 1)
    |> delitem(@dark_crystal, 1)
    |> set_char_var(:mao_morocc2, 22)
    |> close()
    |> hide_portrait()
  end

  defp explains_the_pattern(ctx) do
    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What should we do now?")
      |> mes("You know, that voice.. Do you think it was Satan Morocc...?")
      |> next()
      |> cutin("moc2_rin01", 2)
      |> mes("[Rin]")
      |> mes("..Maybe.")
      |> mes("B.ased on what the more normal Rayan has told us,")
      |> mes("it seems that another personality within him was forcibly created by Satan Morocc.")
      |> next()
      |> mes("[Rin]")
      |> mes("Satan Morocc must have chosen Rayan to break his seal.")
      |> mes("He's been controlling Rayan from deep inside his mind..")
      |> next()
      |> mes("[Rin]")
      |> mes(
        "And... That Mad Rayan seems to have a connection with your Bloody Crystal of Darkness."
      )
      |> next()
      |> cutin("moc2_rin02", 2)
      |> mes("[Rin]")
      |> mes(
        "I didn't see that side of Rayan until you came; he was very cooperative and feeble up until then."
      )
      |> next()
      |> mes("[Rin]")
      |> mes(
        "The original Rayan seemed to remember everything that happened while he was controlled by that mad personality.."
      )
      |> next()
      |> mes("[Rin]")
      |> mes(
        "He was in shock after learning that he's killed all his comrades with his own hand."
      )
      |> mes(
        "He started acting differently once you approached him. I must record all of this in the journal."
      )
      |> next()
      |> next()
      |> mes("[Rin]")
      |> mes(
        "Right. He completely changed once he touched the crystal, as if he himself became Satan Morocc."
      )
      |> next()
      |> cutin("moc2_rin03", 2)
      |> mes("[Rin]")
      |> mes("..Damn it.")
      |> next()
      |> select(["What should we do now?"])

    draw = Enum.random(1..3)
    pattern = Enum.at(@patterns, draw - 1)

    ctx
    |> cutin("moc2_rin02", 2)
    |> mes("[Rin]")
    |> mes("Don't worry.")
    |> mes("I've marked Rayan's body in case he ran away.")
    |> mes("We can trace him down.")
    |> next()
    |> mes("[Rin]")
    |> mes(
      "I'll give you the pattern number of his magic wavelength. Can you give the number to Echinacea?"
    )
    |> mes("She'll take care of the rest.")
    |> next()
    |> mes("[Rin]")
    |> mes("The pattern number is...")
    |> mes("^4d4dff[#{pattern}]^000000")
    |> mes("Don't leave out even one character. Okay?")
    |> set_char_var(:mao_morocc2, 22 + draw)
    |> give_item(@tracing_log, 1)
    |> changequest(7030, 7030 + draw)
    |> next()
    |> mes("[Rin]")
    |> mes("Here, bring this journal with you.")
    |> mes("Please don't forget the pattern number. Alright? Make sure that Echinacea gets it.")
    |> close()
    |> hide_portrait()
  end

  defp reminder(ctx, pattern) do
    ctx
    |> cutin("moc2_rin01", 2)
    |> mes("[Rin]")
    |> mes("Report to Echinacea in the Ash Vacuum, and give her the pattern number.")
    |> mes(
      "The pattern number is ^4d4dff[#{pattern}]^000000. Don't leave out even one character. Okay?"
    )
    |> close()
    |> hide_portrait()
  end

  defp forgotten_pattern(ctx, pattern) do
    ctx
    |> cutin("moc2_rin01", 2)
    |> mes("[Rin]")
    |> mes("Ouch, my head...")
    |> mes("Yes? Why are you back again?")
    |> mes("What...you forgot the pattern number?")
    |> mes("Sigh...Oh well.")
    |> next()
    |> mes("[Rin]")
    |> mes("Make sure you don't forget it again. The pattern number is...")
    |> mes("^4d4dff[#{pattern}]^000000. Don't leave out even one character. Okay?")
    |> mes("Got it?")
    |> next()
    |> mes("[Rin]")
    |> mes("Sigh. Get going, then...")
    |> mes("I need to take a break...")
    |> close()
    |> hide_portrait()
  end
end
