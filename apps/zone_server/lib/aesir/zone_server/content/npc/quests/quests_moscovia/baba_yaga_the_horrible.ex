defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.BabaYagaTheHorrible do
  @moduledoc """
  Baba Yaga drives the Banish Winter quest, trading a spell against winter for her life.

  ## Behavior

  - Walking into her hut before the quest throws the player back into the dungeon; a level 60+
    player carrying 40 or more Yaga Pestles corners her and starts the quest instead.
  - A low-level pestle carrier loses 1 to 20 Yaga Pestles on the first encounter.
  - Once cornered, she offers to banish winter if the player helps gather the spell materials.
  - She dictates the ingredient list; interrupting her about the Sticky Mucus drops it from the
    list.
  - She takes the ingredients plus one Diamond (1, 2 or 3 carat), then sends the player after
    the Magic Gourd Bottle in the dragon's lair.
  - With the bottle she explains how to collect the villagers' wishes, takes it back afterwards,
    and finally hands over the Yaga Secret Medicine once the potion is brewed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 215,
        y: 46,
        dir: 5,
        sprite: 970,
        name: "Baba Yaga, the Horrible",
        scope: :shared,
        trigger: {7, 7}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @speaker "[Baba Yaga, the Horrible]"
  @yaga_pestle 7762
  @magic_gourd_bottle 7761
  @ingredients [
    {940, 20},
    {908, 5},
    {7006, 20},
    {1061, 10},
    {7041, 10},
    {1051, 1},
    {990, 5},
    {7097, 10}
  ]
  @sticky_mucus {938, 10}
  @diamonds [730, 731, 732]

  @impl true
  def on_event("OnTouch", ctx) do
    stage = get_char_var(ctx, :mos_nowinter, 0)
    if stage in [0, 1], do: confront_intruder(ctx, stage), else: ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :mos_nowinter, 0) do
      stage when stage in [0, 1] -> throw_back_to_dungeon(ctx)
      2 -> plead_for_life(ctx)
      3 -> renew_bargain(ctx)
      4 -> ask_to_reconsider(ctx)
      5 -> dictate_ingredients(ctx)
      stage when stage in [6, 7] -> collect_ingredients(ctx, stage)
      8 -> warn_about_dragon(ctx, "Unless you want to be killed,")
      9 -> receive_gourd_bottle(ctx)
      10 -> remind_wish(ctx)
      stage when stage in 11..13 -> complain_about_soldiers(ctx)
      14 -> take_gourd_bottle(ctx)
      stage when stage in [15, 16] -> explain_brewing(ctx)
      17 -> retry_brewing(ctx)
      18 -> hand_over_medicine(ctx)
      19 -> send_off(ctx)
      _ -> refuse_visit(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp confront_intruder(ctx, stage) do
    ctx = mes(ctx, @speaker)
    carries_pestles = count_item(ctx, @yaga_pestle) > 39
    level = base_level(ctx)

    cond do
      carries_pestles and level > 59 ->
        ctx
        |> set_char_var(:mos_nowinter, 2)
        |> mes("Who the hell are you.")
        |> mes("You want me to kick your ass!")
        |> next()
        |> mes(@speaker)
        |> mes("No. They are...")
        |> next()
        |> mes(@speaker)
        |> mes("You have our Yaga Pestles!")
        |> mes("You have so many of them...")
        |> next()
        |> mes(@speaker)
        |> mes("Who, who are you?")
        |> close()

      stage == 0 ->
        ctx
        |> set_char_var(:mos_nowinter, 1)
        |> first_taunt(carries_pestles)
        |> close2()
        |> warp("mosk_dun02", 53, 217)

      true ->
        ctx
        |> repeat_taunt(carries_pestles)
        |> close2()
        |> warp("mosk_dun02", 53, 217)
    end
  end

  defp first_taunt(ctx, true) do
    ctx
    |> mes("Hohoho~")
    |> mes("You cannot beat my friends!")
    |> mes("I don't know where you got")
    |> mes("those Yaga Pestles, but")
    |> mes("give them back to me!")
    |> delitem(@yaga_pestle, Enum.random(1..20))
  end

  defp first_taunt(ctx, false) do
    ctx |> mes("Who the hell are you?") |> mes("You want me to kick your ass!")
  end

  defp repeat_taunt(ctx, true) do
    ctx =
      ctx
      |> mes("You, chicken,")
      |> mes("I need to kick your ass more.")
      |> next()
      |> mes(@speaker)

    if sex(ctx) == 1 do
      ctx
      |> mes("I will bewitch")
      |> mes("and enslave you.")
      |> mes("Come here, Heeee!")
    else
      ctx
      |> mes("Recently, I have no appetite.")
      |> mes("But you will be")
      |> mes("a good appetizer.")
      |> mes("Come here, Heeeeeeeee.")
    end
  end

  defp repeat_taunt(ctx, false) do
    ctx
    |> mes("I need to kick your ass more.")
    |> mes("Come here")
    |> mes("to play a game")
    |> mes("Heeeeeeeeeeee")
  end

  defp throw_back_to_dungeon(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Hohoho")
    |> mes("I need to kick your ass more.")
    |> mes("Come here,")
    |> mes("to play a game.")
    |> mes("Heeeeeeeee.")
    |> close2()
    |> warp("mosk_dun02", 53, 217)
  end

  defp plead_for_life(ctx) do
    {ctx, present_choice} =
      ctx
      |> mes(@speaker)
      |> mes("Let me live, leave me alone, and don't come near me.")
      |> mes("Stop, I am hungry and scared.")
      |> next()
      |> mes("-She is blabbing something weird.-")
      |> next()
      |> mes(@speaker)
      |> mes("Yes, if you let me live, I will compensate you")
      |> mes("with a present, how about that?")
      |> next()
      |> select(["A present?", "I don't need."])

    ctx = if present_choice == 1, do: offer_pestles(ctx), else: ctx

    {ctx, _} =
      ctx
      |> mes(@speaker)
      |> mes("Kaaaaaaaaaak!")
      |> mes("Please, let me live,")
      |> mes("I will do anything you want.")
      |> next()
      |> mes(@speaker)
      |> mes("Don't you need any cream for wounds")
      |> mes("or indigestion?")
      |> mes("They are a bit dirty,")
      |> mes("but very useful.")
      |> next()
      |> select(["Well..."])

    ctx
    |> mes(@speaker)
    |> mes("How about this?")
    |> mes("I bewitch this country so that")
    |> mes("the winter will never come here again.")
    |> next()
    |> mes(@speaker)
    |> mes("I guess that people will like it and")
    |> mes("I'm sure that the Csar")
    |> mes("will award you for it.")
    |> next()
    |> mes(@speaker)
    |> mes("Ah? You seem")
    |> mes("interested... ya?")
    |> mes("What do you think about that?")
    |> next()
    |> select(["Good, but I think you're lying.", "I am not interested."])
    |> case do
      {ctx, 1} ->
        swear_honesty(ctx)

      {ctx, _} ->
        ctx
        |> mes(@speaker)
        |> mes("Akkk... What on earth did you do to me...")
        |> next()
        |> mes("Hmm... What do you want...")
        |> set_char_var(:mos_nowinter, 3)
        |> close()
    end
  end

  defp offer_pestles(ctx) do
    {ctx, _} =
      ctx
      |> mes(@speaker)
      |> mes("Yes, if you let me live")
      |> mes("I will give you the Yaga Pestles")
      |> mes("Aren't you gathering them?")
      |> next()
      |> select(["I don't need them anymore."])

    ctx
  end

  defp swear_honesty(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Sure, you can trust me.")
    |> mes("It is so complicated that I cannot")
    |> mes("perform it on my own")
    |> mes("I am not a liar.")
    |> next()
    |> mes(@speaker)
    |> mes("But, the problem is...")
    |> next()
    |> mes(@speaker)
    |> mes("I am not able to get the materials necessary")
    |> mes("because I don't feel good.")
    |> next()
    |> mes(@speaker)
    |> mes("So,")
    |> mes("if you give me a hand,")
    |> mes("I can use the magic that")
    |> mes("stops winter from returning. Will you help me?")
    |> next()
    |> select(["Ok, I will.", "No. I don't like it."])
    |> case do
      {ctx, 1} ->
        accept_bargain(ctx)

      {ctx, _} ->
        ctx
        |> mes(@speaker)
        |> mes("Heeeek,")
        |> mes("Just, just I need a little help.. It is really little.")
        |> next()
        |> mes(@speaker)
        |> mes("Please, don't kill me...")
        |> next()
        |> mes("'Hmmm, what should I do...'")
        |> set_char_var(:mos_nowinter, 4)
        |> close()
    end
  end

  defp renew_bargain(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Akkkk!")
    |> mes("You came back..")
    |> next()
    |> mes(@speaker)
    |> mes("If you tell the Csar that")
    |> mes("winter won't come back again")
    |> mes("he will reward you.")
    |> next()
    |> mes(@speaker)
    |> mes("Isn't that better for you")
    |> mes("than hurting me?")
    |> next()
    |> select(["Ok, tell me the story.", "Let me think..."])
    |> case do
      {ctx, 1} -> retell_spell(ctx)
      {ctx, _} -> think_more(ctx)
    end
  end

  defp retell_spell(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Certainly, trust me.")
    |> mes("It is so complicated that I cannot")
    |> mes("perform it on my own")
    |> mes("I am not a liar.")
    |> next()
    |> mes(@speaker)
    |> mes("The problem is...")
    |> next()
    |> mes(@speaker)
    |> mes("I am not able to get the materials necessary")
    |> mes("because I don't feel good.")
    |> next()
    |> mes(@speaker)
    |> mes("So,")
    |> mes("if you give me a hand.")
    |> mes("I can use the magic that")
    |> mes("stops winter from returning. Will you help me?")
    |> next()
    |> select(["Ok, I will.", "No. I don't like it."])
    |> case do
      {ctx, 1} ->
        accept_bargain(ctx)

      {ctx, _} ->
        ctx
        |> mes(@speaker)
        |> mes("Heeeeek,")
        |> mes("Just, just I need a little help.. It is really little.")
        |> next()
        |> mes(@speaker)
        |> mes("Please, don't kill me...")
        |> next()
        |> mes("'Hmm... what should I do...'")
        |> set_char_var(:mos_nowinter, 4)
        |> close()
    end
  end

  defp ask_to_reconsider(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("You just need to help little,")
    |> mes("really little...")
    |> next()
    |> mes(@speaker)
    |> mes("Well, did you change your mind?")
    |> next()
    |> select(["Ok, let's try.", "Let me think more..."])
    |> case do
      {ctx, 1} -> accept_bargain(ctx)
      {ctx, _} -> think_more(ctx)
    end
  end

  defp think_more(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("You think more...")
    |> mes("What do you want from me...")
    |> close()
  end

  defp accept_bargain(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Ah, do you accept?")
    |> mes("Thank you.")
    |> next()
    |> mes(@speaker)
    |> mes("Well, I thank you for your kindness.")
    |> mes("Let's cooperate and")
    |> mes("make my Secret Medicine.")
    |> next()
    |> mes(@speaker)
    |> mes("Let me see... Ah...")
    |> next()
    |> mes(@speaker)
    |> mes("It is not used often.")
    |> mes("I don't remember")
    |> mes("where it is.")
    |> mes("Could you please come back later?")
    |> set_char_var(:mos_nowinter, 5)
    |> setquest(18070)
    |> close()
  end

  defp dictate_ingredients(ctx) do
    {ctx, mucus_choice} =
      ctx
      |> mes(@speaker)
      |> mes("Let me see...where the season spell...")
      |> next()
      |> mes("rummaging...")
      |> next()
      |> mes(@speaker)
      |> mes("Ah, here it is... I found it!")
      |> mes("Hoook~ Hoook~")
      |> next()
      |> mes("-What a dusty old book!-")
      |> next()
      |> mes(@speaker)
      |> mes("Well, open your ears.")
      |> mes("It is so rare around here that")
      |> mes("it is not easy for you to remember at once.")
      |> next()
      |> mes(@speaker)
      |> mes("Above all,")
      |> mes("I need 20 Grasshopper's Legs...")
      |> next()
      |> mes(@speaker)
      |> mes("Cough, cough,")
      |> mes("Kaaak, Kaaaaak")
      |> next()
      |> mes(@speaker)
      |> mes("Sniff, sniff.")
      |> mes("5 Spawn...")
      |> next()
      |> mes(@speaker)
      |> mes("eh... and...")
      |> mes("20 Wings Of Red Bat...")
      |> next()
      |> mes(@speaker)
      |> mes("Let me see...")
      |> mes("a glue, no, to cast a spell")
      |> mes("10 Sticky Mucus...")
      |> next()
      |> select(["...Are you sure?", "A glue? You want me to kill you?!"])

    with_mucus = mucus_choice == 1

    ctx
    |> react_to_doubt(with_mucus)
    |> next()
    |> mes(@speaker)
    |> mes("Where were we...")
    |> mes("Cough, cough, cough!")
    |> next()
    |> mes(@speaker)
    |> mes("Ah, yes. Next elements are")
    |> mes("essential.")
    |> next()
    |> mes(@speaker)
    |> mes("10 Witched Starsand")
    |> mes("10 Fine Grits...")
    |> mes("Hooook, hooook~")
    |> mes("Ekkkk, what a dusty book!")
    |> next()
    |> mes(@speaker)
    |> mes("Next is for")
    |> mes("something hot.")
    |> mes("1 Detonator")
    |> mes("5 Red Blood,")
    |> mes("and 10 Burning Hearts.")
    |> next()
    |> mes(@speaker)
    |> mes("Ah, and I need")
    |> mes("a 1, 2, or 3 carat")
    |> mes("^ff0000Diamond^000000.")
    |> next()
    |> mes(@speaker)
    |> mes("Ok, I am repeating the items.")
    |> mes("Eh, they are...")
    |> next()
    |> mes(@speaker)
    |> recap_ingredients(with_mucus)
    |> next()
    |> mes(@speaker)
    |> mes("I am preparing to make it,")
    |> mes("you should get me them quickly. Cough, cough!")
    |> close()
  end

  defp react_to_doubt(ctx, true) do
    ctx
    |> mes(@speaker)
    |> mes("Yes, yes, I am certain. Why don't you trust me...")
    |> next()
    |> mes(@speaker)
    |> mes("Cough, cough,")
    |> mes("I am coughing now, so do not disturb me,")
    |> mes("you write them down.")
  end

  defp react_to_doubt(ctx, false) do
    ctx
    |> mes(@speaker)
    |> mes("No, It just...")
    |> next()
    |> mes(@speaker)
    |> mes("Ehhh, terrible.")
    |> mes("Hey, relax your hand and")
    |> mes("keep writing.")
    |> mes("Forget the Sticky Mucus...")
  end

  defp recap_ingredients(ctx, true) do
    ctx
    |> mes("^ff000020 Grasshopper's Legs,")
    |> mes("5 Spawn,")
    |> mes("20 Wing Of Red Bat,")
    |> mes("10 Sticky Mucus,")
    |> mes("10 Witched Starsand^000000...")
    |> next()
    |> mes(@speaker)
    |> mes("^ff000010 Fine Grit,")
    |> mes("1 Detonator,")
    |> mes("5 Red Blood,")
    |> mes("10 Burning Heart^000000 and,")
    |> mes("a 1, 2, or 3 carat")
    |> mes("^ff00001 Diamond^000000.")
    |> set_char_var(:mos_nowinter, 6)
    |> changequest(18070, 18071)
  end

  defp recap_ingredients(ctx, false) do
    ctx
    |> mes("^ff000020 Grasshopper's Legs,")
    |> mes("5 Spawn,")
    |> mes("20 Wing Of Red Bat,")
    |> mes("10 Witched Starsand^000000...")
    |> next()
    |> mes(@speaker)
    |> mes("^ff000010 Fine Grit,")
    |> mes("1 Detonator,")
    |> mes("5 Red Blood,")
    |> mes("10 Burning Heart^000000 and,")
    |> mes("a 1, 2, or 3 carat")
    |> mes("^ff0000Diamond^000000.")
    |> set_char_var(:mos_nowinter, 7)
    |> changequest(18070, 18072)
  end

  defp collect_ingredients(ctx, stage) do
    ctx =
      ctx
      |> mes(@speaker)
      |> mes("Ehhh... You came back earlier.")
      |> next()
      |> mes(@speaker)
      |> mes("I'm almost prepared..")
      |> mes("Did you get")
      |> mes("all of the items?")
      |> next()

    ingredients = if stage == 6, do: @ingredients ++ [@sticky_mucus], else: @ingredients

    has_ingredients =
      Enum.all?(ingredients, fn {item, amount} -> count_item(ctx, item) >= amount end)

    diamond = Enum.find(@diamonds, &Rathena.truthy?(count_item(ctx, &1)))

    if has_ingredients and diamond != nil do
      ingredients
      |> Enum.reduce(ctx, fn {item, amount}, ctx -> delitem(ctx, item, amount) end)
      |> delitem(diamond, 1)
      |> changequest(if(stage == 6, do: 18071, else: 18072), 18073)
      |> set_char_var(:mos_nowinter, 8)
      |> send_to_dragon_lair()
    else
      ask_for_missing_ingredients(ctx, stage)
    end
  end

  defp send_to_dragon_lair(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Right, you got them all.")
    |> mes("With this amount.. For some time...")
    |> mes("No, to make the Secret Medicine,")
    |> mes("These are enough, cough.")
    |> next()
    |> mes(@speaker)
    |> mes("Let me see, we have all")
    |> mes("that we need...")
    |> next()
    |> mes(@speaker)
    |> mes("Ehhhh...")
    |> mes("Huk!")
    |> next()
    |> mes(@speaker)
    |> mes("Cough, cough, cough!")
    |> mes("Eh... I mean...")
    |> next()
    |> mes(@speaker)
    |> mes("Have you heard the story of")
    |> mes("a dragon sleeping for a long time?")
    |> mes("Next thing that I need is")
    |> mes("something from that dragon, kkkk.")
    |> next()
    |> mes(@speaker)
    |> mes("You can find a funny-shaped bottle")
    |> mes("in the dragon's lair.")
    |> mes("It's a gourd bottle that can")
    |> mes("contain people's speech.")
    |> mes("I must have this.")
    |> next()
    |> mes(@speaker)
    |> mes("I don't know how strong you are,")
    |> mes("but I would like to recommend that")
    |> mes("you avoid fighting that dragon, Kaaaaak~")
    |> next()
    |> mes(@speaker)
    |> mes("Then, release me.")
    |> mes("I want to do something,")
    |> mes("...but, my life is the priority. Yes, it is... Cough, cough!")
    |> close()
  end

  defp ask_for_missing_ingredients(ctx, stage) do
    ctx =
      ctx
      |> mes(@speaker)
      |> mes("I think")
      |> mes("I need more, cough, cough!")
      |> next()
      |> mes(@speaker)
      |> mes("I am not able to do")
      |> mes("anything without them.")
      |> mes("I am repeating the items in the list,")
      |> mes("you should get them all, kaaaaak!")
      |> next()
      |> mes(@speaker)
      |> mes("^ff000020 Grasshopper's Legs,")
      |> mes("5 Spawn,")
      |> mes("20 Wings Of Red Bat")

    ctx = if stage == 6, do: mes(ctx, "10 Sticky Mucus,"), else: ctx

    ctx
    |> mes("10 Witch Starsand^000000...")
    |> next()
    |> mes(@speaker)
    |> mes("^ff000010 Fine Grit,")
    |> mes("1 Detonator,")
    |> mes("5 Red Blood")
    |> mes("10 Burning Hearts^000000 and")
    |> mes("a 1, 2, or 3 carat")
    |> mes("^ff0000Diamond^000000.")
    |> next()
    |> mes(@speaker)
    |> mes("Cough, cough.")
    |> mes("Hu, I talked so much")
    |> mes("that it hurts me, Kaaaak~")
    |> close()
  end

  defp warn_about_dragon(ctx, warning) do
    ctx
    |> mes(@speaker)
    |> mes("It is very, very hard to return alive")
    |> mes("from a lair of a dragon")
    |> mes("without strength and courage.")
    |> next()
    |> mes(@speaker)
    |> mes(warning)
    |> mes("you'd better forget")
    |> mes("the magic gourd bottle, cough!")
    |> close()
  end

  defp receive_gourd_bottle(ctx) do
    if Rathena.truthy?(count_item(ctx, @magic_gourd_bottle)) do
      explain_wish_collection(ctx)
    else
      warn_about_dragon(ctx, "Unless you want to be killed")
    end
  end

  defp explain_wish_collection(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Akkkk?")
    |> mes("Did you really bring it")
    |> mes("from the lair of the dragon...?")
    |> next()
    |> mes(@speaker)
    |> mes("You are superbly great.")
    |> mes("I don't know whether")
    |> mes("you killed the dragon or")
    |> mes("you just stole it from the dragon,")
    |> mes("either way I don't care.")
    |> next()
    |> mes(@speaker)
    |> mes("It is great that")
    |> mes("you've returned alive")
    |> mes("from the lair of the dragon, cough!")
    |> next()
    |> mes(@speaker)
    |> mes("Here, I told you before that")
    |> mes("this gourd bottle can")
    |> mes("contain people's speech")
    |> next()
    |> mes(@speaker)
    |> mes("The next thing that we have to do")
    |> mes("is to receive sincere speeches from")
    |> mes("people with this bottle.")
    |> next()
    |> mes(@speaker)
    |> mes("The important thing is that")
    |> mes("you cannot force them to speak.")
    |> mes("For example, you cannot tell them")
    |> mes("to say 'I don't want winter to come.'")
    |> next()
    |> mes(@speaker)
    |> mes("You should have them")
    |> mes("speak naturally.")
    |> mes("Ah, one more thing that")
    |> mes("you have to take care to remember.")
    |> next()
    |> mes(@speaker)
    |> mes("You need to have the")
    |> mes("voices of three people.")
    |> mes("From a child, a young person and a")
    |> mes("middle aged person.")
    |> next()
    |> mes(@speaker)
    |> mes("The magic is not just witchcraft")
    |> mes("This type of magic is effective")
    |> mes("only by embodying the desires of people.")
    |> next()
    |> mes(@speaker)
    |> mes("Take care of yourself, cough, cough.")
    |> set_char_var(:mos_nowinter, 10)
    |> changequest(18074, 18075)
    |> close()
  end

  defp remind_wish(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("To make the magic,")
    |> mes("I need you to contain")
    |> mes("the wish phrase 'I don't want winter to come.'")
    |> mes("from the three people, kkk.")
    |> next()
    |> mes(@speaker)
    |> mes("But, one thing that you need to remember")
    |> mes("is, do not force them to say it!")
    |> next()
    |> mes(@speaker)
    |> mes("Next,")
    |> mes("you should contain the word from")
    |> mes("a child, a young man and a middle aged man.")
    |> next()
    |> mes(@speaker)
    |> mes("Well, take care of yourself.")
    |> mes("Cough, cough, cough!")
    |> close()
  end

  defp complain_about_soldiers(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("My place has been revealed, cough, cough.")
    |> mes("because of you!")
    |> next()
    |> mes(@speaker)
    |> mes("What did you do outside?")
    |> mes("The soldiers of the Csar are")
    |> mes("surrounding here so that")
    |> mes("I cannot go out.")
    |> close()
  end

  defp take_gourd_bottle(ctx) do
    ctx =
      ctx
      |> mes(@speaker)
      |> mes("Did you do")
      |> mes("what I told")
      |> mes("you to do?")
      |> next()

    if Rathena.truthy?(count_item(ctx, @magic_gourd_bottle)) do
      hand_over_recipe_book(ctx)
    else
      ctx
      |> mes(@speaker)
      |> mes("Where is the Gourd Bottle?")
      |> mes("I can't do anything without it.")
      |> mes("Cough, cough!")
      |> close()
    end
  end

  defp hand_over_recipe_book(ctx) do
    ctx
    |> delitem(@magic_gourd_bottle, 1)
    |> mes(@speaker)
    |> mes("Anyway, give me the bottle and")
    |> mes("think about")
    |> mes("what to do, cough!")
    |> next()
    |> mes(@speaker)
    |> mes("This bottle will be")
    |> mes("used later and now,")
    |> mes("the last step remains")
    |> mes("to complete the work.")
    |> mes("Pass me the book.")
    |> next()
    |> mes(@speaker)
    |> mes("My abilities are deteriorating")
    |> mes("and magic should only be")
    |> mes("done by a single person.")
    |> mes("So, you must compound the materials yourself,")
    |> mes("kaaaaak!")
    |> next()
    |> mes(@speaker)
    |> mes("I know it is hard to do,")
    |> mes("but it is the magic that")
    |> mes("embodies and reveals")
    |> mes("people's desires.")
    |> mes("It is useless unless you put your")
    |> mes("full effort into it, cough!")
    |> next()
    |> mes(@speaker)
    |> mes("Ok, you see that book??")
    |> mes("The letters on the book ")
    |> mes("are illegible,")
    |> mes("But you'll be able to read it 'cuz")
    |> mes("I added comments under the lines for you.")
    |> next()
    |> mes(@speaker)
    |> mes("Read carefully and just follow what")
    |> mes("it tells you.")
    |> mes("The magic is complete.")
    |> mes("Do your best,")
    |> mes("Cough!")
    |> set_char_var(:mos_nowinter, 15)
    |> close()
  end

  defp explain_brewing(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Magic does not come from")
    |> mes("something mysterious.")
    |> next()
    |> mes(@speaker)
    |> mes("It is your effort")
    |> mes("that makes magic.")
    |> mes("There is a saying,")
    |> mes("if you really want it,")
    |> mes("it will happen, cough!")
    |> next()
    |> mes(@speaker)
    |> mes("Here, according to the book")
    |> mes("put the materials in the pot and")
    |> mes("boil them for some time.")
    |> close()
  end

  defp retry_brewing(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Ehmmm...")
    |> mes("Don't you think that")
    |> mes("something is wrong?")
    |> next()
    |> mes(@speaker)
    |> mes("Well, try it again.")
    |> mes("We still have enough materials.")
    |> set_char_var(:mos_nowinter, 16)
    |> close()
  end

  defp hand_over_medicine(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Let me see, hmm!")
    |> next()
    |> mes(@speaker)
    |> mes("Hmm, this might be your first time, but")
    |> mes("this is good.")
    |> mes("You may be talented, kkkk.")
    |> next()
    |> mes(@speaker)
    |> mes("Now then, we are in the final step.")
    |> mes("I'll put the medicine in the bottle,")
    |> mes("you break it by dropping it")
    |> mes("in the center of the town.")
    |> next()
    |> mes(@speaker)
    |> mes("If you do this, what the villagers want")
    |> mes("will be happening,")
    |> mes("forever.")
    |> give_item(7765, 1)
    |> set_char_var(:mos_nowinter, 19)
    |> changequest(18077, 18078)
    |> close()
  end

  defp send_off(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("You just drop the bottle")
    |> mes("in the middle of the village")
    |> mes("to break it.")
    |> next()
    |> mes(@speaker)
    |> mes("And then,")
    |> mes("It doesn't matter to me")
    |> mes("if you tell the whole town or")
    |> mes("report to the Csar to be praised.")
    |> next()
    |> mes(@speaker)
    |> mes("But, don't come back to me, cough, cough.")
    |> close()
  end

  defp refuse_visit(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Hey,")
    |> mes("I told you")
    |> mes("to never come back, cough.")
    |> next()
    |> mes(@speaker)
    |> mes("Stop disturbing me.")
    |> close()
  end
end
