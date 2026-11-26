defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Rogue do
  @moduledoc """
  Arian administers the item-gathering portion of The Sign quest.

  ## Behavior

  - Assigns sequential item deliveries and confiscates subsequent items carried early.
  - Directs the player through Ganaan's test and rewards successful answers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 115,
        y: 154,
        dir: 5,
        sprite: 810,
        name: "Rogue",
        scope: :shared,
        unique_name: "Rogue#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    cond do
      checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second! Right now,")
        |> mes(
          "you have too many items in your inventory. Please come back after you've freed up more inventory space.^000000"
        )
        |> close()

      get_char_var(ctx, :sign_q, 0) < 3 ->
        emotion(ctx, :think)

      get_char_var(ctx, :sign_q, 0) == 3 ->
        introduction(ctx)

      get_char_var(ctx, :sign_q, 0) < 15 ->
        quest_stage(ctx, get_char_var(ctx, :sign_q, 0))

      true ->
        ctx
        |> mes("[Arian]")
        |> mes("...")
        |> mes("Shaddup and")
        |> mes("lemme alone!")
        |> mes("I'm thinking about")
        |> mes("solving world hunger")
        |> mes("here! Or somethin' like that.")
        |> emotion(:think)
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp introduction(ctx) do
    ctx =
      ctx
      |> mes("[Arian]")
      |> mes("...")
      |> mes("Who the hell")
      |> mes("are you, jerkface?")
      |> next()

    options =
      Rathena.concat(
        Rathena.concat("Metz sent me here.:^0000FF", char_name(ctx, 0)),
        "^000000.:Who are you then?"
      )

    {ctx, choice} = select(ctx, String.split(options, ":"))

    case choice do
      1 ->
        ctx
        |> mes("[Arian]")
        |> mes("Oh yeah...?")
        |> mes("Well, I'm sending you")
        |> mes("back! No way I'm fallin'")
        |> mes("for that trick, chump!")
        |> close2()
        |> warp("morocc", 279, 173)

      2 ->
        ctx
        |> mes("[Arian]")
        |> mes("Wha...?")
        |> mes(Rathena.concat(Rathena.concat("^0000FF", char_name(ctx, 0)), "^000000?"))
        |> mes("Yeah, okay. Metz did")
        |> mes("mention something about")
        |> mes("about you. You're here")
        |> mes("for the test, right?")
        |> next()
        |> mes("[Arian]")
        |> mes("Alright, this")
        |> mes("test is simple.")
        |> mes("I tell you to bring me")
        |> mes("a bunch of items and")
        |> mes("you go get them.")
        |> next()
        |> mes("[Arian]")
        |> mes("I know you jerkward adventurers")
        |> mes(
          "are always talking and you share the answers for any test some dude is givin' out. 'Course, it doesn't help that I use the same test"
        )
        |> mes("every frickin' time...")
        |> next()
        |> mes("[Arian]")
        |> mes("Now, you gotta bring and only")
        |> mes(
          "have the item I ask you for when you come to me. If you know that I'll be asking for something later and you happen to have it, I'll straight up ^FF0000jack it^000000."
        )
        |> next()
        |> mes("[Arian]")
        |> mes("The first item?")
        |> mes("Gimme ^FF0000100 Fluff^000000.")
        |> mes("Bring that and I'll")
        |> mes("tell you what to")
        |> mes("bring next.")
        |> set_char_var(:sign_q, 4)
        |> close()

      3 ->
        ctx
        |> mes("[Arian]")
        |> mes("...")
        |> mes("......")
        |> next()
        |> mes("[Arian]")
        |> mes("...")
        |> mes("......")
        |> mes("Your mom.")
        |> mes("Now get the")
        |> mes("hell outta here!")
        |> specialeffect(:firehit)
        |> percent_heal(hp: -50, sp: 0)
        |> close()

      _ ->
        ctx
    end
  end

  defp quest_stage(ctx, stage) when stage in 4..9 do
    items = [{914, 100}, {7033, 50}, {904, 30}, {930, 20}, {1038, 15}, {7013, 10}]
    remaining = Enum.drop(items, stage - 4)
    [{item, amount} | later_items] = remaining
    ctx = mes(ctx, "[Arian]")
    ctx = if stage == 9, do: ctx, else: mes(ctx, "...")

    if count_item(ctx, item) >= amount do
      ctx
      |> delitem(item, amount)
      |> confiscate(later_items)
      |> delivery_complete(stage)
    else
      delivery_missing(ctx, stage)
    end
  end

  defp quest_stage(ctx, 10) do
    ctx
    |> ganaan_directions()
    |> set_char_var(:sign_q, 11)
    |> close()
  end

  defp quest_stage(ctx, 11) do
    ctx
    |> ganaan_directions()
    |> next()
    |> mes("[Arian]")
    |> mes("You wanna leave me")
    |> mes("alone now and gimme")
    |> mes("a little personal space?!")
    |> mes("I need a break from looking")
    |> mes("at your ugly mug, you know?")
    |> close()
  end

  defp quest_stage(ctx, 12) do
    ctx
    |> mes("[Arian]")
    |> mes("Let's see...")
    |> mes("I'm looking at your")
    |> mes("answers and they totally")
    |> mes("suck. Take the test again")
    |> mes("and do it right this time!")
    |> next()
    |> mes("[Arian]")
    |> mes("Geez...")
    |> mes("You're givin' Ganaan")
    |> mes("a hard time. You hear")
    |> mes("me? That's my job!")
    |> set_char_var(:sign_q, 11)
    |> close()
  end

  defp quest_stage(ctx, 13) do
    ctx =
      ctx
      |> mes("[Arian]")
      |> mes("Alright. The answers")
      |> mes("you gave Ganaan tell me")
      |> mes("you're not a total dumbass.")
      |> mes(
        "Now you're supposed to go see Daewoon in Payon. And don't forget to show him this Star thingee."
      )

    renewal = Rathena.truthy?(checkre(ctx, 3))
    level = base_level(ctx)

    experience =
      cond do
        level < 60 -> 300
        level < 70 -> 750
        level < 80 -> 1_000
        level < 90 -> 1_300
        true -> 1_800
      end

    ctx
    |> getexp(if(renewal, do: experience, else: experience * 10), 0)
    |> set_char_var(:sign_q, 14)
    |> give_item(7177, 1)
    |> close()
  end

  defp quest_stage(ctx, 14) do
    ctx
    |> mes("[Arian]")
    |> mes("...........")
    |> mes("Payon...?")
    |> mes("Daewoon?")
    |> mes("Any of it ring a bell?")
    |> mes("Cuz it really oughtta!")
    |> close()
  end

  defp quest_stage(ctx, _stage), do: ctx

  defp ganaan_directions(ctx) do
    ctx
    |> mes("[Arian]")
    |> mes("...")
    |> mes("Alright. Go talk")
    |> mes("to the guy to my left.")
    |> mes("The dude at the counter.")
    |> mes("What's-his-face, Ganaan.")
  end

  defp confiscate(ctx, []), do: ctx

  defp confiscate(ctx, [{item, amount} | rest]) do
    if count_item(ctx, item) >= amount do
      ctx |> delitem(item, amount) |> confiscate(rest)
    else
      ctx
    end
  end

  defp delivery_missing(ctx, 4) do
    ctx
    |> mes("Hey. What the hell's wrong")
    |> mes("with you? Hurry and get me")
    |> mes("^FF0000100 Fluff^000000, ya slacker.")
    |> close()
  end

  defp delivery_missing(ctx, 5) do
    ctx
    |> mes("Hey. What part of 'Get me")
    |> mes("^FF000050 Poison Spores^000000 or I'll")
    |> mes("kick your ass,' don't")
    |> mes("you understand?")
    |> close()
  end

  defp delivery_missing(ctx, 6) do
    ctx
    |> mes("What, your mom drop you on the")
    |> mes("head right after you were born?")
    |> mes("Stop bein' stupid and get me")
    |> mes("^FF000030 Scorpion Tails^000000, nimrod.")
    |> close()
  end

  defp delivery_missing(ctx, 7) do
    ctx
    |> mes("Is it really that hard to get")
    |> mes("^FF000020 Rotten Bandages^000000? Cuz if it")
    |> mes("is, then you must really blow.")
    |> mes("Now hustle it up, punk!")
    |> close()
  end

  defp delivery_missing(ctx, 8) do
    ctx
    |> mes("I don't get it.")
    |> mes("You don't have the")
    |> mes("^FF000015 Little Evil Horn^000000")
    |> mes("I told you to get.")
    |> next()
    |> mes("[Arian]")
    |> mes("I see, so it's my")
    |> mes("fault for not telling you")
    |> mes("not to bring your crap face")
    |> mes("back without 'em. ^333333*A-hem*^000000")
    |> mes("Don't bring your crap face here without 15 Little Evil Horns!!")
    |> close()
  end

  defp delivery_missing(ctx, 9) do
    ctx
    |> mes("I don't care how pretty")
    |> mes("they are or if you're ruining")
    |> mes("the ecosystem! When I say")
    |> mes("''bring ^FF000010 Coral Reefs^000000,'' you")
    |> mes("better have them! All the")
    |> mes("fish can die for all I care.")
    |> close()
  end

  defp delivery_complete(ctx, 4) do
    ctx
    |> mes("Alright, that looks like")
    |> mes("enough Fluff. Now, go and")
    |> mes("get me ^FF000050 Poison Spores^000000.")
    |> set_char_var(:sign_q, 5)
    |> close()
  end

  defp delivery_complete(ctx, 5) do
    ctx
    |> mes("It's about time you")
    |> mes("got here with those")
    |> mes("Poison Spores. Now, go")
    |> mes("and get ^FF000030 Scorpion Tails^000000.")
    |> set_char_var(:sign_q, 6)
    |> close()
  end

  defp delivery_complete(ctx, 6) do
    ctx
    |> mes("Damn, you sure took your")
    |> mes("sweet time bringing over this")
    |> mes("over this crap. Okay, now bring")
    |> mes("^FF000020 Rotten Bandages^000000.")
    |> set_char_var(:sign_q, 7)
    |> close()
  end

  defp delivery_complete(ctx, 7) do
    ctx
    |> mes("You brought the bandages.")
    |> mes("Okay short stuff, go and get")
    |> mes("me ^FF000015 Little Evil Horn^000000. What")
    |> mes("are you waiting for, a memo?")
    |> mes("Get outta here~!")
    |> set_char_var(:sign_q, 8)
    |> close()
  end

  defp delivery_complete(ctx, 8) do
    ctx
    |> mes("My grandma coulda grown")
    |> mes("out her beard in the time")
    |> mes("it tookyou to come back.")
    |> mes("Now hurry it up and get")
    |> mes("me ^FF000010 Coral Reefs^000000!")
    |> set_char_var(:sign_q, 9)
    |> close()
  end

  defp delivery_complete(ctx, 9) do
    ctx
    |> mes("Finally you're back.")
    |> mes("Gimme a sec to count")
    |> mes("all this stuff so I can make")
    |> mes("sure you're not trying to")
    |> mes("cheat. God help you if you")
    |> mes("try to pull a fast one on me...!")
    |> set_char_var(:sign_q, 10)
    |> close()
  end
end
