defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Niren do
  @moduledoc """
  High Priestess Niren assists with the monastery investigation and the quest for peace.

  ## Behavior

  - Discusses the monastery investigation and accepts its journal.
  - Helps the player advance the effort to restore peace in Arunafeltz.

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
        map: "ra_temple",
        x: 165,
        y: 57,
        dir: 5,
        sprite: 915,
        name: "Niren",
        scope: :shared,
        unique_name: "Niren#ss"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{907, 200}]) == 0 do
      ctx
      |> mes("^3355FFWait a second!")
      |> mes("Right now, you're carrying")
      |> mes("too many things with you.")
      |> mes("Please come back after")
      |> mes("using the Kafra Service")
      |> mes("to store some of your items.^000000")
      |> close()
    else
      start_conversation(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp start_conversation(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("ra_gwoman", 2)
      |> mes("[High Priestess Niren]")
      |> mes("So you wanted to talk to me?")
      |> mes("I'm pretty tired right now, but")
      |> mes("I can spare a moment or two.")
      |> mes("What would you like to ask?")
      |> next()
      |> select(["Ask About Veins Smugglers", "Ask About Zhed"])

    case choice do
      1 -> ctx |> discuss_smugglers() |> cutin("ra_gwoman", 255)
      2 -> ctx |> discuss_zhed() |> cutin("ra_gwoman", 255)
      _ -> ctx
    end
  end

  defp discuss_smugglers(ctx) do
    cond do
      get_char_var(ctx, :aru_monas, 0) == 12 ->
        ctx =
          ctx
          |> mes("[Niren]")
          |> mes("Veins smugglers...")
          |> mes("Would you explain")
          |> mes("exactly what you mean")
          |> mes("by Veins smugglers?")
          |> next()
          |> mes("[Niren]")
          |> mes("Oh, them. Yes, I know")
          |> mes("a little bit about them.")
          |> mes("I'm afraid that I can't really")
          |> mes("disclose certain information")
          |> mes("about them since they're")
          |> mes("a classified case...")
          |> next()
          |> mes("[Niren]")
          |> mes("I'm afraid that I cannot give you information about them easily")
          |> mes("as they mean a lot to us.")
          |> next()

        {ctx, _} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Actually, I was curious")
          |> mes("about who they kidnapped.")
          |> next()
          |> mes("[Niren]")
          |> mes("Oh, well, I suppose")
          |> mes("I can tell you more")
          |> mes("about their captive.")
          |> mes("But first, I'd like to")
          |> mes("ask you for a favor.")
          |> next()
          |> select(["Accept", "Do Not Refuse"])

        ctx
        |> mes("[Niren]")
        |> mes("When we realized the")
        |> mes("kind of hostage the")
        |> mes("smugglers captured, we")
        |> mes("didn't know what to do with")
        |> mes("him. We've had too many")
        |> mes("internal problems to handle...")
        |> next()
        |> mes("[Niren]")
        |> mes("Still, we felt that we")
        |> mes("could use him in our plan,")
        |> mes("so we held him in a secret")
        |> mes("place whose location is only")
        |> mes("known to a few people. But")
        |> mes("then... We lost all contact.")
        |> next()
        |> mes("[Niren]")
        |> mes("We sent investigators, but")
        |> mes("we still have no idea what")
        |> mes("happened. All they found was")
        |> mes("a message left by one survivor:")
        |> mes("''They're all demons.'' The")
        |> mes("hostage is probably dead.")
        |> next()
        |> mes("[Niren]")
        |> mes("He may have been a high")
        |> mes("ranking official, but we")
        |> mes("were too preoccupied")
        |> mes("with other matters. In fact,")
        |> mes("I haven't gotten the chance")
        |> mes("to think of what to do with him...")
        |> next()
        |> mes("[Niren]")
        |> mes("I want to ask you to")
        |> mes("go to that place, and")
        |> mes("figure out what happened")
        |> mes("there, and if that high ranking")
        |> mes("official from Rune-Midgarts is")
        |> mes("still alive. I doubt it, but...")
        |> next()
        |> mes("[Niren]")
        |> mes("The investigators we employ")
        |> mes("in our temple usually pale")
        |> mes("in comparison to you foreign")
        |> mes("adventurers, so I have faith")
        |> mes("that you can do it. Still,")
        |> mes("it'll be quite dangerous.")
        |> next()
        |> mes("[Niren]")
        |> mes("If you can do this, I'll")
        |> mes("tell you the location of")
        |> mes("that place: we usually call")
        |> mes("it the monastery. It used to")
        |> mes("be an actual monastery, but we")
        |> mes("use it to hold captives now.")
        |> next()
        |> mes("[Niren]")
        |> mes("I'm sorry, but I can't tell")
        |> mes("you anything else about that")
        |> mes("old place. It's located to the")
        |> mes("southwest of Veins across the")
        |> mes("sea. You should be able to find")
        |> mes("a boat at South Veins Beach.")
        |> next()
        |> mes("[Niren]")
        |> mes("However... Never mind.")
        |> mes("I'd like to help you more,")
        |> mes("but I'd be compromising my")
        |> mes("position. I'm sorry. Please")
        |> mes("come back and tell me if")
        |> mes("you learn anything there.")
        |> set_char_var(:aru_monas, 13)
        |> next()
        |> mes("[Niren]")
        |> mes("I'll send a message to the")
        |> mes("magistrate of Veins. If you")
        |> mes("talk to him, he'll provide you")
        |> mes("with some useful information")
        |> mes("for your journey. Good luck.")
        |> close2()

      get_char_var(ctx, :aru_monas, 0) < 18 ->
        ctx
        |> mes("[Niren]")
        |> mes("Going to the monastery")
        |> mes("isn't the problem: coming")
        |> mes("back here alive will probably")
        |> mes("be the real challenge for you.")
        |> next()
        |> mes("[Niren]")
        |> mes("We can't send any troops")
        |> mes("there until we understand")
        |> mes("what they'd be confronting")
        |> mes("there. That's why we need")
        |> mes("you to investigate the area.")
        |> close2()

      get_char_var(ctx, :aru_monas, 0) < 25 ->
        ctx
        |> mes("[Niren]")
        |> mes("Still investigating the")
        |> mes("monastery? Perhaps if")
        |> mes("you found any records")
        |> mes("left behind by one of")
        |> mes("the residents over there...")
        |> close2()

      get_char_var(ctx, :aru_monas, 0) == 25 ->
        if count_item(ctx, 7755) < 1 do
          ctx
          |> mes("[Niren]")
          |> mes("Still investigating the")
          |> mes("monastery? Perhaps if")
          |> mes("you found any records")
          |> mes("left behind by one of")
          |> mes("the residents over there...")
          |> close2()
        else
          ctx =
            ctx
            |> mes("[Niren]")
            |> mes("You found this journal")
            |> mes("in the monastery? Perfect.")
            |> mes("Let me read it, and see")
            |> mes("what we can learn...")
            |> next()
            |> mes("[Niren]")
            |> mes("Hmm, this sounds really")
            |> mes("bad. This is tragic, especially")
            |> mes("we kept so many important")
            |> mes("people over there. I'll request")
            |> mes("to dispatch troops there right")
            |> mes("away. Something must be done.")
            |> next()
            |> mes("[Niren]")
            |> mes("There are too many problems")
            |> mes("we have to confront now, but")
            |> mes("this monastery issue needs")
            |> mes("top priority. We won't be able")
            |> mes("to handle it if another threat")
            |> mes("comes from that place.")
            |> delitem(7755, 1)
            |> set_char_var(:aru_monas, 26)

          ctx
          |> getexp(
            if Rathena.truthy?(checkre(ctx, 3)) do
              50_000
            else
              500_000
            end,
            0
          )
          |> close2()
        end

      true ->
        ctx
        |> mes("[Niren]")
        |> mes("I suppose that Arunafeltz")
        |> mes("and Rune-Midgarts will be too")
        |> mes("busy with their own internal")
        |> mes("issues to commit to war.")
        |> mes("High Priest Zhed will be")
        |> mes("glad to know about this.")
        |> close2()
    end
  end

  defp discuss_zhed(ctx) do
    cond do
      get_char_var(ctx, :aru_em, 0) < 10 ->
        ctx
        |> mes("[High Priestess Niren]")
        |> mes("I'm sorry...")
        |> mes("I really don't want")
        |> mes("to think about Zhed")
        |> mes("right now. He's just...")
        |> close2()

      get_char_var(ctx, :aru_em, 0) == 10 ->
        ctx =
          ctx
          |> mes("[High Priestess Niren]")
          |> mes("You wanted to ask me about")
          |> mes("Beken--High Priest Zhed?")
          |> mes("I can't do anything for him.")
          |> mes("He dug his own grave by")
          |> mes("allowing you into the")
          |> mes("holy ground, didn't he?")
          |> next()
          |> mes("[High Priestess Niren]")
          |> mes("I thought I warned you")
          |> mes("before to stay out of trouble.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I'm not here to discuss")
          |> mes("that. But I happened to")
          |> mes("hear that you're the only")
          |> mes("person that can help him now.")
          |> next()
          |> mes("[High Priestess Niren]")
          |> mes("...............................")
          |> mes("...............................")
          |> mes("...............................")
          |> next()
          |> mes("[High Priestess Niren]")
          |> mes("It's true that Zhed and")
          |> mes("I used to work well together,")
          |> mes("but we no longer share the")
          |> mes("same dream. You'd better find")
          |> mes("someone else. Unlike him,")
          |> mes("I actually want a war.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Weren't you guys friends?")
        |> mes("Besides, you don't seem as")
        |> mes("aggressive as those other")
        |> mes("hard liner priests.")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("Aggressive? Hmpf. If you")
        |> mes("take a good look at those")
        |> mes("moderates, you'll see that")
        |> mes("they oppose war, but they're")
        |> mes("also totally corrupt. In fact, they committed worse atrocities!")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("The moderates conducted")
        |> mes("inhumane testing on living")
        |> mes("creatures, even humans!")
        |> mes("And Zhed and I... Could do")
        |> mes("nothing but pray to Freya.")
        |> mes("Only war can this this chaos!")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("We need to start all")
        |> mes("over again. I can't help")
        |> mes("Zhed. Please leave...")
        |> next()
        |> mes("^3355FFIt doesn't look like")
        |> mes("you can change High")
        |> mes("Priestess Niren's mind.")
        |> mes("For now, you'd better talk")
        |> mes("to High Priest Zhed.^000000")
        |> set_char_var(:aru_em, 11)
        |> changequest(2132, 2133)
        |> close2()

      get_char_var(ctx, :aru_em, 0) == 11 or get_char_var(ctx, :aru_em, 0) == 12 ->
        ctx
        |> mes("[High Priestess Niren]")
        |> mes("I already told you")
        |> mes("how I feel about Zhed.")
        |> mes("We were wrong all along...")
        |> mes("This time, war is the answer.")
        |> close2()

      get_char_var(ctx, :aru_em, 0) == 13 ->
        ctx =
          ctx
          |> mes("[High Priestess Niren]")
          |> mes("I already told you")
          |> mes("how I feel about Zhed.")
          |> mes("We were wrong all along...")
          |> mes("This time, war is the answer.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Fine. If you're so sure")
        |> mes("of yourself, then you won't")
        |> mes("mind reading this letter")
        |> mes("from High Priest Zhed.")
        |> next()
        |> mes("^3355FFNiren angrily grabbed the")
        |> mes("letter, ripped the envelope")
        |> mes("open, and began to read his")
        |> mes("message. Her stern face slowly")
        |> mes("softened as she slowly scanned")
        |> mes("what Zhed had to tell her.^000000")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes(".................")
        |> mes(".................")
        |> mes(".................")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("That Zhed... He always")
        |> mes("did have a way with words.")
        |> mes("I suppose the old saying is")
        |> mes("true: the pen truly is mightier")
        |> mes("than the sword. *Sigh...*")
        |> next()
        |> mes("[Sippie]")
        |> mes("High Priestess")
        |> mes("Niren? Are you okay?")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("Oh, I'm fine,")
        |> mes("thank you. I guess")
        |> mes("I'm just a little tired.")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("...............................")
        |> mes("I have to admit, there's truth")
        |> mes("in what Zhed's saying. We")
        |> mes("have a duty to protect our")
        |> mes("people, the pope, our holy")
        |> mes("ground. But I need to think...")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("Would you give me some")
        |> mes("time to myself? I'll let you")
        |> mes("know once I've made a decision.")
        |> set_char_var(:aru_em, 14)
        |> close2()

      get_char_var(ctx, :aru_em, 0) == 14 ->
        if Enum.random(1..10) == 1 do
          ctx =
            ctx
            |> mes("[High Priestess Niren]")
            |> mes("...................")
            |> mes("...................")
            |> mes("...................")
            |> emotion(:think)
            |> next()
            |> mes("[Sippie]")
            |> mes("High Priestess Niren,")
            |> mes("you must be really tired.")
            |> mes("You look pale for some reason.")
            |> emotion(:profusely_sweat)
            |> next()
            |> mes("[High Priestess Niren]")
            |> mes("I do feel rather drained.")
            |> mes("I don't know why I've been")
            |> mes("holding on to this hatred for")
            |> mes("so long. I guess I can finally")
            |> mes("just cast it to the winds...")
            |> next()
            |> mes("[High Priestess Niren]")
            |> mes("Adventurer...")
            |> mes("What was your name?")
            |> next()

          ctx =
            mes(
              ctx,
              Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]")
            )

          ctx =
            ctx
            |> mes(
              Rathena.concat(
                Rathena.concat("My name is ", char_name(ctx, 0)),
                "."
              )
            )
            |> next()
            |> mes("[High Priestess Niren]")
            |> mes("Adventurer...")
            |> mes("You had the chance to talk")
            |> mes("with our pope once, but I doubt")
            |> mes("you'll be able to do so again")
            |> mes("^3311FFin private^000000. You'll definitely")
            |> mes("need our help for that end.")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Does this mean that")
            |> mes("you've decided to work")
            |> mes("with Zhed again?")
            |> next()
            |> mes("^3355FFNiren quietly nodded")
            |> mes("her head, and then")
            |> mes("resumed talking.^000000")
            |> next()
            |> mes("[High Priestess Niren]")
            |> mes("I'm still not sure if")
            |> mes("I can join him in the long")
            |> mes("run. I mean, talking to the")
            |> mes("pope might not result in")
            |> mes("anything, actually. But")
            |> mes("it's still worth a try.")
            |> next()
            |> mes("[High Priestess Niren]")
            |> mes("However, I've never")
            |> mes("doubted Zhed's dedication")
            |> mes("to Arunafeltz. He deserves")
            |> mes("another chance from me.")
            |> next()
            |> mes("[High Priestess Niren]")
            |> mes("Our pope is always surrounded ")
            |> mes("by priests and followers sent")
            |> mes("by High Priest Vildt. He always")
            |> mes("manages to keep his eyes and")
            |> mes("ears on her. We need to get")
            |> mes("those spies away somehow...")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("What can we do")
            |> mes("about them, then?")
            |> next()
            |> mes("[High Priestess Niren]")
            |> mes("For now, just approach")
            |> mes("the pope as if you just")
            |> mes("wanted to leisurely chat.")
            |> mes("While you're doing that,")
            |> mes("try to gather information")
            |> mes("from the priests around her.")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Sure thing. You")
            |> mes("can count on me!")

          ctx
          |> emotion(:best, playerattached(ctx))
          |> set_char_var(:aru_em, 15)
          |> changequest(2134, 2135)
          |> close2()
        else
          ctx
          |> mes("[High Priestess Niren]")
          |> mes("Ugh, this is giving me")
          |> mes("a headache. There's")
          |> mes("too much to consider...")
          |> mes("Too much at stake here...")
          |> close2()
        end

      get_char_var(ctx, :aru_em, 0) == 15 ->
        ctx
        |> mes("[High Priestess Niren]")
        |> mes("Just approach the pope")
        |> mes("for a chat, and see what")
        |> mes("you can learn from the")
        |> mes("other priests around her.")
        |> close2()

      get_char_var(ctx, :aru_em, 0) == 16 ->
        ctx =
          ctx
          |> mes("[High Priestess Niren]")
          |> mes("How is the pope?")
          |> mes("I haven't had the chance")
          |> mes("to meet her recently, so...")
          |> next()

        ctx =
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("[", char_name(ctx, 0)),
              "]"
            )
          )
          |> mes("Well, she doesn't seem")
          |> mes("very well, just like the")
          |> mes("last time I saw her. I didn't")
          |> mes("learn anything about all those")
          |> mes("priests. Just that they've been")
          |> mes("working in the temple non-stop.")
          |> next()
          |> mes("[High Priestess Niren]")
          |> mes("Yes, they've been by her")
          |> mes("side twenty-fours a day.")
          |> mes("It's been like that for years.")
          |> next()
          |> emotion(:kek)
          |> mes("[Sippie]")
          |> mes("Oh, High Priestess Niren,")
          |> mes("I love working for you, but")
          |> mes("sometimes I wish I could leave")
          |> mes("just to see my family. Even")
          |> mes("just once a year would be nice.")
          |> next()
          |> emotion(:aha)
          |> mes("[High Priestess Niren]")
          |> mes("...............................")
          |> mes("You're absolutely right.")
          |> mes("That gives me an idea.")
          |> next()
          |> emotion(:delight)
          |> mes("[Sippie]")
          |> mes("Huh? What is it?")
          |> next()
          |> mes("[High Priestess Niren]")
          |> mes("You all need a vacation.")
          |> next()
          |> mes("[High Priestess Niren]")

        ctx =
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("", char_name(ctx, 0)),
              "."
            )
          )
          |> next()

        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("Yes?")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("I should reward everyone")
        |> mes("in the Sky Garden for their")
        |> mes("contribution. However,")
        |> mes("they were hired by Vildt,")
        |> mes("so I can't directly give them")
        |> mes("leave for vacation. Hmm...")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("Sippie...")
        |> mes("I'll need a pen")
        |> mes("and some paper.")
        |> next()
        |> mes("[Sippie]")
        |> mes("Yes, ma'am.")
        |> mes("There you go!")
        |> cutin("ra_gwoman", 255)
        |> next()
        |> mes("^3355FF*Scribble Scribble*^000000")
        |> mes("^3355FF*Scribble Scribble*^000000")
        |> mes("^3355FF*Scribble Scribble*^000000")
        |> mes("^3355FF*Scribble Scribble*^000000")
        |> next()
        |> cutin("ra_gwoman", 2)
        |> mes("[High Priestess Niren]")
        |> mes("I administered a blessing")
        |> mes("for a child from a native")
        |> mes("family, and they were very")
        |> mes("grateful since most of the")
        |> mes("priests shun the natives.")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("It turns out that this")
        |> mes("child is gifted at forgery.")
        |> mes("She doesn't like being too")
        |> mes("close to other people, but")
        |> mes("that's beside the point.")
        |> mes("Here, take this letter.")
        |> next()
        |> mes("[High Priestess Niren]")
        |> mes("Ah, and take this file that")
        |> mes("contains a sample of Vildt's")
        |> mes("handwriting. Bring them to")
        |> mes("a girl named Ishmael in a")
        |> mes("village in North Rachel.")
        |> mes("I hope she'll help us...")
        |> set_char_var(:aru_em, 17)
        |> give_item(7343, 1)
        |> changequest(2136, 2137)
        |> close2()

      get_char_var(ctx, :aru_em, 0) == 17 ->
        ctx
        |> mes("[High Priestess Niren]")
        |> mes("Please deliver my letter")
        |> mes("and that file to Ishmael in")
        |> mes("North Rachel. Hopefully,")
        |> mes("she can use her talents")
        |> mes("to help us out.")
        |> close2()

      get_char_var(ctx, :aru_em, 0) == 19 ->
        if count_item(ctx, 7343) > 0 do
          ctx =
            ctx
            |> mes("[High Priestess Niren]")
            |> mes("Have you met with Ishmael?")
            |> next()
            |> mes("^3355FFYou handed Niren the")
            |> mes("file forged by Ishmael.^000000")
            |> next()
            |> emotion(:stare)
            |> mes("[High Priestess Niren]")
            |> mes("Perfect! This forgery is")
            |> mes("so well done, I'm sure")
            |> mes("that even Vildt won't be")
            |> mes("know if he wrote it or not.")
            |> next()
            |> mes("[High Priestess Niren]")

          ctx =
            ctx
            |> mes(
              Rathena.concat(
                Rathena.concat("", char_name(ctx, 0)),
                "..."
              )
            )
            |> mes("I'm going to use this to")
            |> mes("send the priests and followers")
            |> mes("on vacation. Then me and Zhed")
            |> mes("can talk to the pope without")
            |> mes("any unecessary interruptions.")
            |> next()
            |> mes("[High Priestess Niren]")
            |> mes("I really don't want to burden")
            |> mes("our pope with what Zhed and I")
            |> mes("have to say... But that's much")
            |> mes("preferable to doing nothing")
            |> mes("and experiencing the downfall")
            |> mes("of our beloved Arunafeltz.")
            |> next()
            |> mes("[High Priestess Niren]")
            |> mes("Sippie, please")
            |> mes("deliver this vacation")
            |> mes("approval to the priests and")
            |> mes("followers in the Sky Garden.")
            |> next()
            |> mes("[Sippie]")
            |> mes("Yes, ma'am!")
            |> next()
            |> mes("[High Priestess Niren]")

          ctx =
            ctx
            |> mes(
              Rathena.concat(
                Rathena.concat("", char_name(ctx, 0)),
                ","
              )
            )
            |> mes("please go back to Zhed,")
            |> mes("and let him know everything")
            |> mes("is ready. Then I want you to")
            |> mes("meet us in the ^3131FFSky Garden^000000.")
            |> next()

          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("[", char_name(ctx, 0)),
              "]"
            )
          )
          |> mes("Yes!")
          |> next()
          |> mes("[High Priestess Niren]")
          |> mes("We need to hurry and")
          |> mes("do this before High")
          |> mes("Priest Vildt realizes")
          |> mes("what we are doing.")
          |> delitem(7343, 1)
          |> set_char_var(:aru_em, 20)
          |> changequest(2139, 2140)
          |> close2()
        else
          ctx
          |> mes("^3131FFYou seem to have")
          |> mes("misplaced Ishmael's file.^000000")
          |> close2()
        end

      get_char_var(ctx, :aru_em, 0) == 20 or get_char_var(ctx, :aru_em, 0) == 21 ->
        ctx
        |> mes("[High Priestess Niren]")
        |> mes("Please hurry back")
        |> mes("to High Priest Zhed.")
        |> close2()

      get_char_var(ctx, :aru_em, 0) == 22 ->
        ctx =
          ctx
          |> mes("[High Priestess Niren]")
          |> mes("I'm so proud of our pope!")
          |> mes("Did you hear her wonderful")
          |> mes("speech? Well, I should say")
          |> mes("those are the words of Freya,")
          |> mes("but... Well, you know. Hohoho!")
          |> next()
          |> mes("[High Priestess Niren]")
          |> mes("Our priests may have acted")
          |> mes("selfishly, but they are still")
          |> mes("committed to Arunafeltz's")
          |> mes("welfare. Things should")
          |> mes("change for the better now.")
          |> next()
          |> mes("[High Priestess Niren]")
          |> mes("I'm ashamed that I strayed")
          |> mes("from the path of peace and")
          |> mes("almost endangered my country.")
          |> mes("I'm glad Zhed brought me back")
          |> mes("my senses. From now on, I'll")
          |> mes("repent for my sins with Zhed.")
          |> next()
          |> mes("[High Priestess Niren]")
          |> mes("I hope the goddess can")
          |> mes("forgive me. Ah, and you")
          |> mes("should know that Zhed is")
          |> mes("waiting for you. Why don't")
          |> mes("you go see him now?")
          |> next()
          |> mes("^3355FFNiren softly smiles")
          |> mes("at you, and you realize")
          |> mes("that it's the first time")
          |> mes("that you've seen that")
          |> mes("expression on her face.^000000")
          |> set_char_var(:aru_em, 23)

        ctx
        |> getexp(
          if Rathena.truthy?(checkre(ctx, 3)) do
            100_000
          else
            1_000_000
          end,
          0
        )
        |> changequest(2141, 2142)
        |> close2()

      get_char_var(ctx, :aru_em, 0) > 21 ->
        ctx
        |> mes("[High Priestess Niren]")
        |> mes("Thanks to you and")
        |> mes("Bekento, I think I've")
        |> mes("finally found my way.")
        |> close2()

      true ->
        ctx
        |> mes("[High Priestess Niren]")
        |> mes("I'm sorry...")
        |> mes("I really don't want")
        |> mes("to think about Zhed")
        |> mes("right now. He's just...")
        |> close2()
    end
  end
end
