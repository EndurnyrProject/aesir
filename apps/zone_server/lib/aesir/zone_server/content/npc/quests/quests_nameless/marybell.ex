defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Marybell do
  @moduledoc """
  Marybell helps investigate the Z Gang for the Rogue Guild.

  ## Behavior

  - She tests the player, shares leads, and advances the investigation as it progresses.

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
      %{map: "in_rogue", x: 359, y: 116, dir: 3, sprite: 747, name: "Marybell", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :zdan_edq, 0)

    cond do
      progress == 4 -> password(ctx)
      progress in 5..6 -> gambler_reminder(ctx)
      progress == 7 -> gambler_victory(ctx)
      progress == 8 -> discuss_gang(ctx)
      progress in 9..10 -> recruitment_lead(ctx)
      progress == 11 -> decoder_lead(ctx)
      progress in 12..13 -> decoder_reminder(ctx)
      progress == 14 -> hideout_lead(ctx)
      progress in 15..17 -> hideout_reminder(ctx)
      progress > 18 -> celebration(ctx)
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:thief) -> guild_greeting(ctx)
      true -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp password(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Marybell]")
      |> mes("Hey. What do you want?")
      |> next()
      |> select(["Password"])

    case choice do
      1 -> ask_password(ctx)
      _ -> ctx
    end
  end

  defp ask_password(ctx) do
    {ctx, password} =
      ctx
      |> mes("[Marybell]")
      |> mes("Can't hear you.")
      |> mes("Come a little closer,")
      |> mes("and talk right in my ear.")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", password)

    if get_local(ctx, :"input$", "") == "The dawn is yet to come." do
      trusted_visitor(ctx)
    else
      wrong_password(ctx)
    end
  end

  defp trusted_visitor(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Marybell]")
      |> mes("Valdes sent you?!")
      |> mes("I'm surprised he finally")
      |> mes("decided to talk to someone!")
      |> mes("Alright, if you're his friend,")
      |> mes("then I'll do what I can to")
      |> mes("help. What do you need?")
      |> next()
      |> select(["Ask About Z Gang", "Valdes says, ''Hi.''"])

    case choice do
      1 ->
        ctx
        |> mes("[Marybell]")
        |> mes("The Z Gang again?")
        |> mes("I guess he's still mad")
        |> mes("about capturing them.")
        |> mes("It's not a big deal for me")
        |> mes("to tell you what I know, but")
        |> mes("can I really trust you?")
        |> next()
        |> mes("[Marybell]")
        |> mes("Let me test you out.")
        |> mes("Go to Payon, find an old")
        |> mes("guy named Moonho Ahn. He's")
        |> mes("a legendary gambler better")
        |> mes("known as the White Meteor.")
        |> mes("If he trusts you, I trust you.")
        |> next()
        |> mes("[Marybell]")
        |> mes("Heh, but he'll only trust")
        |> mes("you if you can beat him at")
        |> mes("gambling. Whether you return")
        |> mes("or not, I'm gonna continue")
        |> mes("investigating the Z Gang for")
        |> mes("the Rogue Guild and Valdes.")
        |> changequest(3122, 3123)
        |> set_char_var(:zdan_edq, 5)
        |> gambler_reminder()

      2 ->
        valdes_greeting(ctx)

      _ ->
        ctx
    end
  end

  defp wrong_password(ctx) do
    ctx =
      ctx
      |> mes("[Marybell]")
      |> mes("Can't tell what")
      |> mes("you're saying exactly.")
      |> next()

    if sex(ctx) == 1 do
      ctx
      |> mes("[Marybell]")
      |> mes("If this is some kind")
      |> mes("of weird come-on, you'd")
      |> mes("better have something")
      |> mes("better to say than that!")
      |> close()
    else
      ctx
      |> mes("[Marybell]")
      |> mes("What, are you coming")
      |> mes("on to me? I'm down with")
      |> mes("any gender, but, heh,")
      |> mes("you sure about this?")
      |> mes("Hahahahahahahahaha!")
      |> close()
    end
  end

  defp valdes_greeting(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("Weird. It's not like him")
    |> mes("to send his regards like that.")
    |> mes("He's not sick or anything,")
    |> mes("is he? If he's still drinking")
    |> mes("the next time I see him,")
    |> mes("I'm gonna clobber that guy!")
    |> next()
    |> mes("[Marybell]")
    |> mes("Geez. Doesn't he know")
    |> mes("I volunteered for this")
    |> mes("job for his sake? Oh well,")
    |> mes("it's really nice to know")
    |> mes("that he's thinking of me.")
    |> mes("What? Rogues can have friends!")
    |> close()
  end

  defp gambler_reminder(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("Let me test you out.")
    |> mes("Go to Payon, find an old")
    |> mes("guy named Moonho Ahn. He's")
    |> mes("a legendary gambler better")
    |> mes("known as the White Meteor.")
    |> mes("If he trusts you, I trust you.")
    |> close()
  end

  defp gambler_victory(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("What, you're back?")
    |> mes("Aww, nuts! That signature")
    |> mes("on your arm... You really")
    |> mes("beat him? How the hell--?")
    |> next()
    |> set_char_var(:zdan_edq, 8)
    |> mes("[Marybell]")
    |> mes("Wait, lemme check")
    |> mes("and make sure. Yeap.")
    |> mes("That's the one. That's")
    |> mes("the signature he used when")
    |> mes("he was the White Meteor.")
    |> next()
    |> mes("[Marybell]")
    |> mes("How did you beat him?")
    |> mes("Last time, he cleaned me")
    |> mes("out of all my money! You")
    |> mes("must be some kinda genius")
    |> mes("to beat that guy. Heh. Guess")
    |> mes("I underestimated you.")
    |> next()
    |> mes("[Marybell]")
    |> mes("Hold on, before anything")
    |> mes("else, I gotta tell everyone")
    |> mes("that someone actually beat")
    |> mes("the White Meteor. They're")
    |> mes("totally not gonna believe it!")
    |> close()
  end

  defp recruitment_lead(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("Oh, and one more thing...")
    |> mes("I hear that they're trying")
    |> mes("to secretly recruit more")
    |> mes("gang members in Morocc.")
    |> mes("The nerve of those guys...! ")
    |> next()
    |> mes("[Marybell]")
    |> mes("I haven't heard anything")
    |> mes("else, but would you let me")
    |> mes("know if you get any new leads?")
    |> mes("The Rogue Guild wants these")
    |> mes("Z Gang guys really bad!")
    |> close()
  end

  defp decoder_lead(ctx) do
    ctx =
      ctx
      |> mes("[Marybell]")
      |> mes("Hey, I've been looking for")
      |> mes("you! One of the Rogues")
      |> mes("dispatched to Comodo found")
      |> mes("this envelope on a Z Gang")
      |> mes("informer. Could be a clue!")
      |> next()
      |> mes("[Marybell]")
      |> mes("What's weird is that the")
      |> mes("informer was fighting so")
      |> mes("hard to hold on to blank")
      |> mes("piece of paper... But we ")
      |> mes("know that's not really")
      |> mes("the case here, is it?")
      |> next()
      |> mes("[Marybell]")
      |> mes("They must've been using")
      |> mes("some kinda secret invisible")
      |> mes("ink. Anyway, I gave the paper")
      |> mes("to a professional decoder to")
      |> mes("crack, and he oughta be")
      |> mes("done by now. Anyway...")
      |> next()
      |> mes("[Marybell]")
      |> mes("I thought maybe you'd")
      |> mes("want to go talk to him,")
      |> mes("see if he's finished with it.")
      |> mes("His name's Gooho Ahn over")
      |> mes("in Payon, one of the best")
      |> mes("decoders in this kingdom.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Gooho Ahn?")
    |> mes("Why does it feel like")
    |> mes("I should know that")
    |> mes("name? It's so familiar...")
    |> next()
    |> mes("[Marybell]")
    |> mes("I guess it's 'cause")
    |> mes("Gooho is the younger brother")
    |> mes("of Moonho, that legendary")
    |> mes("gambler you happened to beat.")
    |> next()
    |> mes("[Marybell]")
    |> mes("Eh, that's not what's")
    |> mes("important right now.")
    |> mes("Would you talk to Gooho")
    |> mes("Ahn and see what he found?")
    |> changequest(3128, 3129)
    |> set_char_var(:zdan_edq, 12)
    |> close()
  end

  defp decoder_reminder(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("Hey, why don't you talk")
    |> mes("to Gooho Ahn in Payon,")
    |> mes("and ask if he finished")
    |> mes("decoding that secret letter")
    |> mes("from the Z Gang already?")
    |> close()
  end

  defp hideout_lead(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("Oh, Gooho decoded everything?")
    |> mes("Let's see... Something about")
    |> mes("the Book of Forbidden Mystery... Ah. There we go! The location")
    |> mes("of the Z Gang's hideout!")
    |> mes("Heh heh! We got 'em!")
    |> next()
    |> mes("[Marybell]")
    |> mes("One of the Rogues followed")
    |> mes("the informer carrying this")
    |> mes("letter, but he just vanished")
    |> mes("during the chase... Like, by")
    |> mes("magic, I guess. So we don't")
    |> mes("the hideout's exact place.")
    |> next()
    |> mes("[Marybell]")
    |> mes("Even so, we're definitely")
    |> mes("sure that it's around the")
    |> mes("secret path to the South")
    |> mes("Morocc underground. Um,")
    |> mes("but we can't let you come")
    |> mes("with the Rogue Guild.")
    |> next()
    |> mes("[Marybell]")
    |> mes("Sorry, I know, it's official")
    |> mes("business and all that hooplah.")
    |> mes("Tell you what. We'll each go")
    |> mes("hunt them down separately, and")
    |> mes("whoever finds 'em first gets")
    |> mes("dibs on beating them up!")
    |> changequest(3131, 3132)
    |> set_char_var(:zdan_edq, 15)
    |> close()
  end

  defp hideout_reminder(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("We're definitely sure")
    |> mes("that the Z Gang's hideout")
    |> mes("is near the secret path")
    |> mes("to the South Morocc")
    |> mes("underground. You")
    |> mes("know where that is?")
    |> next()
    |> mes("[Marybell]")
    |> mes("Tell you what. We'll each go")
    |> mes("hunt them down separately, and")
    |> mes("whoever finds 'em first gets")
    |> mes("dibs on beating them up!")
    |> close()
  end

  defp celebration(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("Nice work! You captured")
    |> mes("the Z Gang! The kingdom")
    |> mes("musta given you a really")
    |> mes("big reward, huh?")
    |> next()
    |> mes("[Marybell]")
    |> mes("Valdes really wanted to")
    |> mes("capture them himself, but")
    |> mes("I'm sure he'll be real happy")
    |> mes("to hear the news. Maybe he")
    |> mes("and I can celebrate with")
    |> mes("a little drink later.")
    |> next()
    |> mes("[Marybell]")
    |> mes("Hey, it's been a real")
    |> mes("thrill working with you,")
    |> mes("real thrill. Maybe we can")
    |> mes("team up again for a good")
    |> mes("cause some other time, yeah?")
    |> close()
  end

  defp guild_greeting(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("That Z Gang has been")
    |> mes("a pain the Rogue Guild's")
    |> mes("ass. No one runs away")
    |> mes("from us! Nobody! But...")
    |> mes("They can do it somehow.")
    |> next()
    |> mes("[Marybell]")
    |> mes("There's not much here")
    |> mes("that might interest you,")
    |> mes("but knock yourself out")
    |> mes("if you wanna look around.")
    |> close()
  end

  defp discuss_gang(ctx) do
    ctx
    |> mes("[Marybell]")
    |> mes("Well, I promised to tell")
    |> mes("you what I know about the")
    |> mes("Z Gang, so I gotta make good.")
    |> mes("What did you want to ask me?")
    |> next()
    |> gang_questions()
  end

  defp gang_questions(ctx) do
    {ctx, choice} =
      select(ctx, [
        "Z Gang's Goal",
        "Z Gang's Recent Movements",
        "Z Gang's Stronghold",
        "Thanks for the tip!"
      ])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Marybell]")
          |> mes("Actually, I don't know")
          |> mes("what they plan to do, but")
          |> mes("obviously it isn't something")
          |> mes("very good. Personally, I think")
          |> mes("they just want to harass")
          |> mes("people as much as they can.")
          |> next()
          |> mes("[Marybell]")
          |> mes("You could conquer the")
          |> mes("world, I guess, with that")
          |> mes("Book of Forbidden Mystery,")
          |> mes("but I don't think they're")
          |> mes("that... Calculating.")
          |> next()

        ctx |> set_local(:a, get_local(ctx, :a, 0) + 1) |> gang_questions()

      2 ->
        ctx =
          ctx
          |> mes("[Marybell]")
          |> mes("Well, the Z Gang is")
          |> mes("responsible for a series")
          |> mes("of thefts lately. They've")
          |> mes("only been stealing jewels")
          |> mes("like diamonds, rubies,")
          |> mes("emeralds. Not sure why...")
          |> next()

        ctx |> set_local(:b, get_local(ctx, :b, 0) + 1) |> gang_questions()

      3 ->
        ctx =
          ctx
          |> mes("[Marybell]")
          |> mes("Well, we don't know where")
          |> mes("they're hiding out. If that")
          |> mes("was the case, the Z Gang")
          |> mes("would already be caught!")
          |> mes("They even got away from")
          |> mes("us Rogues. Crazy, huh?")
          |> next()
          |> mes("[Marybell]")
          |> mes("The Rogue Guild has got")
          |> mes("the best intel network so...")
          |> mes("The Z Gang probably has")
          |> mes("informers everywhere in")
          |> mes("all the towns. It's the only")
          |> mes("way they can escape us.")
          |> next()
          |> mes("[Marybell]")
          |> mes("Hey, we can use that...")
          |> mes("If we can catch one of")
          |> mes("their informers, one of")
          |> mes("them'll spill the beans")
          |> mes("on where the Z Gang is")
          |> mes("hiding. Worth a shot, yeah?")
          |> next()

        ctx |> set_local(:c, get_local(ctx, :c, 0) + 1) |> gang_questions()

      4 ->
        finish_questions(ctx)

      _ ->
        ctx
    end
  end

  defp finish_questions(ctx) do
    if get_local(ctx, :a, 0) > 0 and get_local(ctx, :b, 0) > 0 and
         get_local(ctx, :c, 0) > 0 do
      ctx
      |> mes("[Marybell]")
      |> mes("Oh, and one more thing...")
      |> mes("I hear that they're trying")
      |> mes("to secretly recruit more")
      |> mes("gang members in Morocc.")
      |> mes("The nerve of those guys...!")
      |> next()
      |> mes("[Marybell]")
      |> mes("It might be a good idea")
      |> mes("for you to go to Morocc")
      |> mes("and check it out. Good")
      |> mes("luck finding those Z Gang")
      |> mes("guys. And take care!")
      |> changequest(3125, 3126)
      |> set_char_var(:zdan_edq, 9)
      |> close()
    else
      ctx
      |> mes("[Marybell]")
      |> mes("Hey, I'm willing to")
      |> mes("let you in on everything")
      |> mes("I know. After all the trouble")
      |> mes("you went through, I'm sure")
      |> mes("you've got a ton of questions!")
      |> next()
      |> gang_questions()
    end
  end
end
