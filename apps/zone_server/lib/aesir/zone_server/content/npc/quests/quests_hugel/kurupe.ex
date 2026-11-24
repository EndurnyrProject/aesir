defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Kurupe do
  @moduledoc """
  Kurupe asks adventurers to help milk Booboo and rewards their work.

  ## Behavior

  - Starts the search for Burupu and grants an initial reward for milking Booboo.
  - Offers repeat milking jobs with randomly selected item rewards.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hugel",
        x: 56,
        y: 104,
        dir: 3,
        sprite: 709,
        name: "Kurupe",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    if base_level(ctx) > 49 and not Rathena.truthy?(get_char_var(ctx, :hg_milk, 0)) do
      ctx
      |> mes("[Kurupe]")
      |> mes("Oh no, what am I gonna")
      |> mes("do?! I need to deliver the")
      |> mes("milk tomorrow, but Burupu")
      |> mes("still hasn't arrived yet!")
      |> emotion(:huk)
      |> next()
      |> mes("[Kurupe]")
      |> mes("When is he coming")
      |> mes("to work? Burupu,")
      |> mes("where are you?!")
      |> emotion(:sweat)
      |> set_char_var(:hg_milk, 1)
      |> close()
    else
      ctx
      |> mes("[Kurupe]")
      |> mes("Why hasn't Burupu")
      |> mes("arrived yet? If he")
      |> mes("doesn't come soon,")
      |> mes("how will I get the milk")
      |> mes("delivered by tomorrow?")
      |> close()
    end
  end

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_milk, 0) do
      1 ->
        ask_for_burupu(ctx)

      stage when stage > 1 and stage < 5 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Burupu, I need you")
        |> mes("to come to work! Maybe")
        |> mes("you can find him practicing")
        |> mes("with his sword right outside")
        |> mes("of town. I hope you can find")
        |> mes("that lazy guy for me...")
        |> close()

      5 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Burupu is making demands?!")
        |> mes("I guess I don't have a choice.")
        |> mes("You wouldn't happen to know")
        |> mes("how much Rapiers cost, do you?")
        |> mes("Why does Burupu want to become")
        |> mes("a Swordman so much, huh?")
        |> close()

      6 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Oh, you're going to")
        |> mes("help me milk the cow?")
        |> mes("Great, great, thanks so")
        |> mes("much! Please milk Booboo")
        |> mes("right away, and get me")
        |> mes("some delicious milk~")
        |> set_char_var(:hg_milk, 7)
        |> close()

      7 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Hmm, how about this?")
        |> mes("If you can actually milk")
        |> mes("Booboo the cow, then I'll")
        |> mes("give you some food. Does")
        |> mes("that sound fair? Anyway,")
        |> mes("please get to work soon~")
        |> close()

      8 ->
        first_reward(ctx)

      9 ->
        offer_repeat(ctx)

      10 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("For now, go talk")
        |> mes("to Burupu and let him")
        |> mes("know that he doesn't need")
        |> mes("to come into work today~")
        |> close()

      11 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Ah, you spoke to")
        |> mes("Burupu already? Good,")
        |> mes("now would you please")
        |> mes("milk Booboo the cow?")
        |> mes("Thanks once again~")
        |> set_char_var(:hg_milk, 12)
        |> close()

      12 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Please go and milk")
        |> mes("Booboo the cow as")
        |> mes("soon as you can, okay?")
        |> close()

      13 ->
        repeat_reward(ctx)

      _ ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Aww, nuts...!")
        |> mes("I've got so many")
        |> mes("Milk deliveries to do")
        |> mes("tomorrow, but what can")
        |> mes("I do without any Milk?!")
        |> close()
    end
  end

  defp ask_for_burupu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kurupe]")
      |> mes("Could Burupu be hiding")
      |> mes("from me again? He's been")
      |> mes("wanting to ditch work more")
      |> mes("and more ever since he wanted")
      |> mes("to become a Swordman. If only")
      |> mes("I could hire someone else...")
      |> next()
      |> mes("[Kurupe]")
      |> mes("Unfortunately, he's the")
      |> mes("only one I can find that")
      |> mes("can actually milk my cow,")
      |> mes("Booboo! If you can find")
      |> mes("Burupu for me, I'll be sure")
      |> mes("to pay you for your effort.")
      |> next()
      |> select(["Sure.", "Sorry, I'm busy."])

    case choice do
      1 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Thank you, you're a")
        |> mes("lifesaver! I need to get the")
        |> mes("milk delivered by tomorrow,")
        |> mes("so I really need Burupu back!")
        |> mes("You should be able to find him")
        |> mes("somewhere just outside of town.")
        |> set_char_var(:hg_milk, 2)
        |> setquest(12040)
        |> close()

      2 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("N-no...!")
        |> mes("If I can't find")
        |> mes("Burupu, then there's no")
        |> mes("way I'd be able to deliver")
        |> mes("the milk orders by tomorrow!")
        |> mes("Great, what am I gonna do?")
        |> close()

      _ ->
        ctx
    end
  end

  defp first_reward(ctx) do
    ctx =
      ctx
      |> mes("[Kurupe]")
      |> mes("Great! Now that you've")
      |> mes("milked Booboo, I can go")
      |> mes("and make my deliveries")
      |> mes("tomorrow! Here's a little")
      |> mes("something to eat as my way")
      |> mes("of saying, ''Thanks a lot~''")
      |> next()

    if checkweight(ctx, [{12063, 3}]) != 1 do
      overweight(ctx)
    else
      ctx = ctx |> set_char_var(:hg_milk, 9) |> specialeffect2(:cone)

      ctx
      |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 10_000, else: 100_000), 0)
      |> give_item(12063, 3)
      |> erasequest(12043)
      |> mes("[Kurupe]")
      |> mes("I always need")
      |> mes("someone to help me")
      |> mes("milk Booboo, especially")
      |> mes("when Burupu doesn't feel")
      |> mes("like doing it, so please come")
      |> mes("by and help me when you can~")
      |> close()
    end
  end

  defp offer_repeat(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kurupe]")
      |> mes("Oh, it's you again!")
      |> mes("Did you want to help me")
      |> mes("out by milking Booboo the")
      |> mes("cow? I can always use a")
      |> mes("dependable person like you.")
      |> next()
      |> select([
        "Sure, I'll milk Booboo.",
        "What'll pay me this time?",
        "Nah, just dropping by."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Great, great! If you want")
        |> mes("to milk Booboo, first tell")
        |> mes("Burupu that he doesn't need")
        |> mes("to come in today, and then")
        |> mes("come back to me. Then, I'll")
        |> mes("let you milk Booboo the cow.")
        |> set_char_var(:hg_milk, 10)
        |> close()

      2 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Let's see...")
        |> mes("Milk Booboo for me this")
        |> mes("time, and I'll randomly")
        |> mes("choose one of the following")
        |> mes("sets of rewards to give you.")
        |> next()
        |> mes("1 set of 5 Milk,")
        |> mes("1 set of 3 Honey,")
        |> mes("1 set of 5 Orange Potions,")
        |> mes("1 set of Yellow Potions, or")
        |> mes("1 Bundle of Food. Hmmm...")
        |> mes("That sounds fair, right?")
        |> close()

      3 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Ahahahah, it's good")
        |> mes("to see you! Now, don't")
        |> mes("be a stranger, alright?")
        |> mes("Burupu could learn a")
        |> mes("couple things from you...")
        |> close()

      _ ->
        ctx
    end
  end

  defp repeat_reward(ctx) do
    ctx =
      ctx
      |> mes("[Kurupe]")
      |> mes("Ah, you've done a good")
      |> mes("job of milking Booboo the")
      |> mes("cow for me. Let's see, let's")
      |> mes("see, what would be good to")
      |> mes("give you as payment. Hmm...")
      |> next()
      |> set_local(:milkreward, Enum.random(1..10))

    reward = get_local(ctx, :milkreward, 0)

    cond do
      reward < 5 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("You know what?")
        |> mes("Why don't you have")
        |> mes("some Milk? It's only")
        |> mes("fitting, after all. Besides,")
        |> mes("it's really good for you!")
        |> mes("Thanks again for your help~")
        |> give_repeat_reward(519, 5)

      reward < 8 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Ah, I've got it!")
        |> mes("You like Orange Potions,")
        |> mes("right? Come on, you looove")
        |> mes("Orange Potions! Here, you can")
        |> mes("have a bunch as my way of saying thanks for milking Booboo the cow~")
        |> give_repeat_reward(502, 5)

      reward < 10 ->
        ctx
        |> mes("[Kurupe]")
        |> mes("Oooh, I could give you")
        |> mes("some Yellow Potions, Yes,")
        |> mes("that's a good idea. Please")
        |> mes("take these Yellow Potions")
        |> mes("as a token of my gratitude")
        |> mes("for milking old Booboo.")
        |> give_repeat_reward(503, 5)

      true ->
        ctx = set_local(ctx, :milkreward, Enum.random(1..10))

        if get_local(ctx, :milkreward, 0) < 7 do
          ctx
          |> mes("[Kurupe]")
          |> mes("Hey, why don't you")
          |> mes("take some fresh Honey?")
          |> mes("Yes, it's sweet, delicious,")
          |> mes("it's everything you could")
          |> mes("ever want! Thanks for")
          |> mes("milking Booboo for me~")
          |> give_repeat_reward(518, 3)
        else
          ctx
          |> mes("[Kurupe]")
          |> mes("Here, why don't you")
          |> mes("have some of this really")
          |> mes("delicious food? I don't")
          |> mes("remember what I packed in")
          |> mes("here, but I'm sure it tastes")
          |> mes("good, and it's good for you~")
          |> give_repeat_reward(12111, 1)
        end
    end
  end

  defp give_repeat_reward(ctx, item, amount) do
    if checkweight(ctx, [{item, amount}]) != 1 do
      ctx |> next() |> overweight()
    else
      ctx
      |> set_char_var(:hg_milk, 9)
      |> erasequest(12043)
      |> give_item(item, amount)
      |> close()
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("[Kurupe]")
    |> mes("Wait a minute!")
    |> mes("Currently you are carrying")
    |> mes("too many items with you.")
    |> mes("Please come back again")
    |> mes("after you store some items into kafra storage.")
    |> close()
  end
end
