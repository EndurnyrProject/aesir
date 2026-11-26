defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.DrunkenMan do
  @moduledoc """
  Geologist Gio recruits the player to investigate Thor Volcano.

  ## Behavior

  - Gives the player a survey assignment and its reference guide.
  - Reveals the scheme and directs the player to collect a reward after the survey.

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
        map: "ve_in",
        x: 233,
        y: 116,
        dir: 3,
        sprite: 901,
        name: "Drunken Man",
        scope: :shared,
        unique_name: "Drunken Man#vol"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :aru_vol, 0) == 7 ->
        begin_survey(ctx)

      get_char_var(ctx, :aru_vol, 0) > 7 and get_char_var(ctx, :aru_vol, 0) < 24 ->
        survey_reminder(ctx)

      get_char_var(ctx, :aru_vol, 0) == 24 ->
        complete_survey(ctx)

      true ->
        ctx |> boast() |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp begin_survey(ctx) do
    ctx = ctx |> boast() |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me, but are")
      |> mes("you the executive director")
      |> mes("of the Veins Geological Team?")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Yeah, sure! Executive")
      |> mes("director, deputy director,")
      |> mes("director, researcher, CEO,")
      |> mes("no... No, wait, that last one")
      |> mes("doesn't sound right. Hah!")
      |> mes("I'm all of those~")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("I'm the executive director...")
      |> mes("I'm the only one that works")
      |> mes("at the institute, really.")
      |> mes("Why, what do you want?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Uhh... There are some")
      |> mes("official notices for you")
      |> mes("at your office. I guess you")
      |> mes("need to get some surveys")
      |> mes("done? They sound like")
      |> mes("they're pretty important.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Maybe...")
      |> mes("Maybe even ^FF0000urgent^000000.")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Wha--? Hey, what day")
      |> mes("is it today? Damn it!")
      |> mes("Fine, fine, time to get")
      |> mes("to work. Just when I was")
      |> mes("really enjoying myself too!")
      |> mes("Argh, I never wanna be sober!")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("But... Working is the")
      |> mes("only way for me to afford")
      |> mes("all this drinking... Such")
      |> mes("is life. Such is life.")
      |> next()
      |> mes("[Ladies]")
      |> mes("Where are you going?")
      |> mes("Can't you stay a bit")
      |> mes("longer and talk with")
      |> mes("us? Pleeeeeease?")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Sorry, ladies,")
      |> mes("but duty calls.")
      |> mes("Hahahahahahha~")
      |> next()

    ctx = emotion(ctx, :throb, getnpcid(ctx, "Drunken Lady#1"))

    ctx =
      ctx
      |> emotion(:throb, getnpcid(ctx, "Drunken Lady#2"))
      |> mes("[Ladies]")
      |> mes("Please don't go~")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Ahem!")
      |> mes("Let's see now.")
      |> mes("What'd be best...?")
      |> mes("..............................")
      |> mes("..............................")
      |> mes("..............................")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("..............................")
      |> mes("..............................")
      |> mes("........................Right!")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Hey, you.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Yes?")
      |> next()
      |> emotion(:best)
      |> mes("[Drunken Man]")
      |> mes("I hereby promote you as")
      |> mes("chief researcher of the")
      |> mes("Veins Geological Research")
      |> mes("Institute. Congratulations!")
      |> mes("Welcome to the team, friend!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Huh...?")
      |> mes("I don't understand")
      |> mes("what you're talking about!")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Heh! You should be grateful")
      |> mes("that I'm accepting you as my")
      |> mes("student! Everyone'd be proud")
      |> mes("to study under me, Gio, the")
      |> mes("world's greatest geologist!")
      |> mes("(Well, maybe.)")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Hey, I never--")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("Ah-ah! Now that you're")
      |> mes("my student, I expect you")
      |> mes("to work hard if you're going")
      |> mes("to learn anything. First thing")
      |> mes("first--go to my office and")
      |> mes("clear up my belated business.")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("Here, take this ^FF0000reference")
      |> mes("guide^000000 with you to my office.")
      |> mes("When you check my desk, you'll")
      |> mes("find a ^FF0000pyrometer^000000 and a ^FF0000report")
      |> mes("form^000000. You'll need to bring all")
      |> mes("that stuff to Thor Volcano.")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("When you get to Thor Volcano,")
      |> mes("use the pryometer to check the")
      |> mes("volcano's temperature, and")
      |> mes("fill out the report form.")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("Take the filled report")
      |> mes("form to the geology camp")
      |> mes("that's deep inside the volcano")
      |> mes("so that they can stamp their")
      |> mes("confirmation on it. That's")
      |> mes("not so hard now, is it?")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("Ahh, I've also decided")
      |> mes("to take these lovely ladies")
      |> mes("on as my students as well~")
      |> mes("I should stay here and")
      |> mes("entreat them to a lecture.")
      |> next()

    ctx = emotion(ctx, :throb, getnpcid(ctx, "Drunken Lady#1"))

    ctx
    |> emotion(:throb, getnpcid(ctx, "Drunken Lady#2"))
    |> mes("[Ladies]")
    |> mes("Oh~! You'll really")
    |> mes("teach us geology?")
    |> next()
    |> mes("[Geologist Gio]")
    |> mes("Oh, right! When they")
    |> mes("ask you about the volcano's")
    |> mes("temperature when you submit")
    |> mes("the report at the geological")
    |> mes("camp, make something up.")
    |> mes("Make sure it sounds bad!")
    |> next()
    |> mes("[Geologist Gio]")
    |> mes("Words like ''explosion,''")
    |> mes("''disaster,'' and ''collatoral")
    |> mes("damage'' would be perfect.")
    |> mes("Just do your part, and I'll")
    |> mes("take care of the rest. Okay~")
    |> mes("Come back soon, my pupil!")
    |> next()
    |> mes("^3355FFWell, this isn't what")
    |> mes("you expected, but you get")
    |> mes("the feeling that this will")
    |> mes("all turn out in your favor.")
    |> mes("You know that feeling, right?^000000")
    |> changequest(2116, 2117)
    |> set_char_var(:aru_vol, 8)
    |> give_item(7705, 1)
    |> close()
  end

  defp survey_reminder(ctx) do
    ctx
    |> mes("[Geologist Gio]")
    |> mes("Hey, you'd better hurry")
    |> mes("it up. I mean, you're the")
    |> mes("one that found that notice")
    |> mes("in my office, didn't you?")
    |> mes("You know how important")
    |> mes("this work is to us!")
    |> next()
    |> mes("[Geologist Gio]")
    |> mes("Get the pyrometer,")
    |> mes("and go to Thor Volcano")
    |> mes("to fill out the report")
    |> mes("form and submit it to")
    |> mes("the geological camp!")
    |> close()
  end

  defp complete_survey(ctx) do
    ctx =
      ctx
      |> mes("[Geologist Gio]")
      |> mes("Well, those are")
      |> mes("nice legs, but they're")
      |> mes("not the best pair I've see--")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I'm back.")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("*Ahem* And that's how")
      |> mes("erosion... Works. Tomorrow,")
      |> mes("I'll teach you ladies all")
      |> mes("about rocks. All of them.")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("Welcome back! So,")
      |> mes("how was the volcanic")
      |> mes("temperature report?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Well, I did what you")
      |> mes("told me. Hey, are you")
      |> mes("sure you wanted me to")
      |> mes("exaggerate the temperature?")
      |> mes("What about the camp?")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("Oh, don't worry about")
      |> mes("the temperature. It's")
      |> mes("supposed to go up.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("What are you...?")
      |> mes("Actually, I thought that")
      |> mes("maybe the pryometer")
      |> mes("might be broken.")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("Heh! You're right~")
      |> mes("I broke it on purpose.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("What?!")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("You know, it's hard for")
      |> mes("scholars like me to make")
      |> mes("a decent living. Hell, I was")
      |> mes("lucky enough to get that")
      |> mes("temperature measuring job")
      |> mes("from the geological camp.")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("Those guys've been trying")
      |> mes("to fire me ever since they")
      |> mes("realized the volcano became")
      |> mes("dormant. But... They can't")
      |> mes("fire me if there's proof that")
      |> mes("it might go off anytime!")
      |> next()
      |> mes("[Geologist Gio]")
      |> mes("Then, when they're all")
      |> mes("panicked, I calmly and")
      |> mes("suavely offer a solution")
      |> mes("that looks like it works.")
      |> mes("Of course, there's never")
      |> mes("a problem to begin with...")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("So...")
    |> mes("You're a con man.")
    |> next()
    |> mes("[Geologist Gio]")
    |> mes("Awww, don't look at")
    |> mes("me like that. I'm a real")
    |> mes("scientist. Come on...")
    |> mes("Oh, come on...")
    |> next()
    |> mes("[Geologist Gio]")
    |> mes("Look, why don't you head")
    |> mes("back to my institute and")
    |> mes("check out my bookshelf?")
    |> mes("I keep a small box there")
    |> mes("where I keep all sorts")
    |> mes("of nifty little goodies.")
    |> next()
    |> mes("[Geologist Gio]")
    |> mes("You can have the very")
    |> mes("first thing that pops out")
    |> mes("of that box. I wonder if the")
    |> mes("goddess will grace you")
    |> mes("with good fortune. You")
    |> mes("might get something good~")
    |> next()
    |> mes("[Geologist Gio]")
    |> mes("Consider it your")
    |> mes("payment for a job")
    |> mes("well done. Good work!")
    |> mes("I expected nothing less")
    |> mes("from my star pupil!")
    |> changequest(60211, 60212)
    |> set_char_var(:aru_vol, 25)
    |> delitem(7342, 1)
    |> delitem(7704, 1)
    |> delitem(7705, 1)
    |> close()
  end

  defp boast(ctx) do
    ctx =
      ctx
      |> mes("[Drunken Man]")
      |> mes("So... ^333333*Urp*^000000")
      |> mes("So then I said...")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("''^3131FFHey, buddy! A man")
      |> mes("uses his back to talk,")
      |> mes("not his fists! You wanna")
      |> mes("piece of me? Bring it on!^000000''")
      |> next()
      |> mes("[Drunken Man]")
      |> mes("Then he got all")
      |> mes("scared, and ran away!")
      |> mes("Hahahaha! Guess I look")
      |> mes("pretty tough, don't I?")
      |> next()

    ctx = emotion(ctx, :throb, getnpcid(ctx, "Drunken Lady#1"))

    ctx
    |> emotion(:throb, getnpcid(ctx, "Drunken Lady#2"))
    |> mes("[Ladies]")
    |> mes("Oh, my God!")
    |> mes("You're so cool~!")
    |> next()
    |> mes("[Drunken Man]")
    |> mes("Well... Anyone would")
    |> mes("have done it. I was just")
    |> mes("being a gentleman.")
    |> mes("Hahahah, that's right!")
  end
end
