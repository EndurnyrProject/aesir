defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsVeins.WincingoldmanVeins do
  @moduledoc """
  Zabaroo asks for help with his work gathering stones.

  ## Behavior

  - Sends the player to Absar and then to the factory for a stone delivery.
  - Rewards the player after the delivery and answers questions about the stones.

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
      %{name: "", scope: :shared, unique_name: "WincingOldMan_veins"},
      %{
        map: "ve_fild02",
        x: 337,
        y: 314,
        dir: 4,
        sprite: 945,
        name: "Wincing Old Man",
        scope: :renewal,
        unique_name: "Wincing Old Man#ve"
      },
      %{
        map: "ve_fild05",
        x: 257,
        y: 130,
        dir: 4,
        sprite: 945,
        name: "Wincing Old Man",
        scope: :pre_renewal,
        unique_name: "Wincing Old Man#ve"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("- Wait a moment! -")
      |> mes("- Currently you are carrying -")
      |> mes("- too many items with you. -")
      |> mes("- Please come back after -")
      |> mes("- you put some items into Kafra Storage. -")
      |> close()
    else
      quest_progress(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp quest_progress(ctx) do
    progress = get_char_var(ctx, :veins_stone, 0)

    cond do
      progress == 0 ->
        offer_help(ctx)

      progress == 1 ->
        ctx
        |> mes("[Zabaroo]")
        |> mes("Thanks for your help.")
        |> mes("If you can't find Absar")
        |> mes("in the Tool Shop, then")
        |> mes("you might want to stop")
        |> mes("by the Tavern. A-auuugh!")
        |> close()

      progress > 1 and progress < 4 ->
        ctx
        |> mes("[Zabaroo]")
        |> mes("Geez, Absar sure can")
        |> mes("be fussy. Still, do your")
        |> mes("best to get what he wants.")
        |> mes("He won't help me otherwise!")
        |> mes("Other than that, he's not")
        |> mes("really that bad a guy...")
        |> close()

      progress == 4 ->
        receive_tool(ctx)

      progress > 4 and progress < 7 ->
        ctx
        |> mes("[Zabaroo]")
        |> mes("Thanks again for your help!")
        |> mes("What did Absar call this")
        |> mes("thing again? A Tactile...")
        |> mes("Extendable... Damn it...")
        |> mes("Why's the name so long?")
        |> mes("Anyway, it's usefull~")
        |> close()

      progress == 7 ->
        reward(ctx)

      progress > 7 ->
        ctx
        |> mes("[Zabaroo]")
        |> mes("Thanks to you and Absar,")
        |> mes("my poor back hasn't been")
        |> mes("bothering me at all lately.")
        |> mes("I should be taking better")
        |> mes("care of myself at my age...")
        |> close()

      true ->
        ctx
    end
  end

  defp offer_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Zabaroo]")
      |> mes("My back is killing me")
      |> mes("after stooping over to")
      |> mes("pick up stones all day long...")
      |> mes("The pain... It's unbearable!")
      |> next()
      |> select(["Bend with your knees, yo.", "Gosh, how bad is it?"])

    case choice do
      1 ->
        ctx
        |> mes("[Zabaroo]")
        |> mes("Whippersnapper!")
        |> mes("I didn't ask you for")
        |> mes("your advice! Don't")
        |> mes("patronize an old man!")
        |> close()

      2 ->
        {ctx, _} =
          ctx
          |> mes("[Zabaroo]")
          |> mes("Oh, it hurts so much, it's")
          |> mes("almost crippling. But I don't")
          |> mes("have any choice. I need to")
          |> mes("get enough stops to fill")
          |> mes("this gap if I want to get")
          |> mes("paid. Arrrrgh, damn it!")
          |> next()
          |> mes("[Zabaroo]")
          |> mes("If I don't get enough")
          |> mes("money to pay for my")
          |> mes("granddaughter's medicine,")
          |> mes("I won't be able to buy any")
          |> mes("medicine for my granddaughter!")
          |> mes("And that will be horrible! Ag!")
          |> next()
          |> select(["Can I help?"])

        {ctx, _} =
          ctx
          |> mes("[Zabaroo]")
          |> mes("I appreciate your kindness,")
          |> mes("stranger, but no. I have")
          |> mes("to do this on my own.")
          |> mes("A man must have his pride....")
          |> next()
          |> mes("^333333*Snap*^000000")
          |> next()
          |> mes("[Zabaroo]")
          |> mes("Argh! My back...!")
          |> mes("This was totally")
          |> mes("unforeseeable!")
          |> mes("Please! Please,")
          |> mes("for the love of Freya,")
          |> mes("please help me!")
          |> next()
          |> select(["I will help you."])

        {ctx, _} =
          ctx
          |> mes("[Zabaroo]")
          |> mes("Thank you!")
          |> mes("Thanks so much!")
          |> next()
          |> select(["What do you want me to do?"])

        ctx
        |> mes("[Zabaroo]")
        |> mes("Ow-ow-ow! Oh... Okay...")
        |> mes("You see those all dark")
        |> mes("stones stuck in the ground?")
        |> mes("Those are what I need to")
        |> mes("pick up. Now don't go")
        |> mes("lifting rocks just yet...")
        |> next()
        |> mes("[Zabaroo]")
        |> mes("I asked some other old")
        |> mes("man in town, Absar, to")
        |> mes("make me something to help")
        |> mes("with my back. He was going")
        |> mes("to help me if I gave hi--")
        |> mes("ARGH! My back! It hurts!")
        |> next()
        |> mes("[Zabaroo]")
        |> mes("It hurts so bad! But it's")
        |> mes("especially painful right")
        |> mes("when I'm about to finish")
        |> mes("sentences in which I intend to")
        |> mes("tell you important informat--")
        |> mes("ARRRGH! Find Absar! Quickly!")
        |> next()
        |> answer_questions()

      _ ->
        ctx
    end
  end

  defp receive_tool(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Zabaroo]")
      |> mes("Oh good, you're back!")
      |> mes("Did you bring what")
      |> mes("Absar made for me?")
      |> next()
      |> select(["Yes, here..."])

    {ctx, _} =
      ctx
      |> mes("[Zabaroo]")
      |> mes("So this is what he")
      |> mes("was talking about?")
      |> mes("How does it... Ah!")
      |> mes("Here we go! If I pull")
      |> mes("the handle, that end of")
      |> mes("the stick will pick stuff up!")
      |> next()
      |> mes("[Zabaroo]")
      |> mes("This is great! I won't")
      |> mes("have to bend over to pick")
      |> mes("up stones anymore! Heh,")
      |> mes("he must be awfully proud")
      |> mes("of this useful invention~")
      |> mes("I can imagine him strutting.")
      |> next()
      |> mes("[Zabaroo]")
      |> mes("Um, did he have anything")
      |> mes("to say after he gave this")
      |> mes("to you? I'm just curious.")
      |> next()
      |> select(["This message..."])

    {ctx, _} =
      ctx
      |> mes("[Zabaroo]")
      |> mes("Oh... I thought he")
      |> mes("would forget all about")
      |> mes("that. Well, it's a relief")
      |> mes("to know that now. That's")
      |> mes("really very nice of him.")
      |> next()
      |> mes("[Zabaroo]")
      |> mes("I hate to ask you...")
      |> mes("But would you mind")
      |> mes("helping me out one")
      |> mes("more time?")
      |> next()
      |> select(["Huh? What is it?"])

    ctx
    |> mes("[Zabaroo]")
    |> mes("Don't worry, it's not")
    |> mes("too hard. Would you just")
    |> mes("deliver the stones I gathered")
    |> mes("to the factory in town? It's")
    |> mes("near the airport or airship or")
    |> mes("something. It won't take long.")
    |> set_char_var(:veins_stone, 5)
    |> close()
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("[Zabaroo]")
      |> mes("Oh, you're back!")
      |> mes("I really appreciate all")
      |> mes("of your help. I don't have")
      |> mes("much, and I know you weren't")
      |> mes("expecting a reward, but I'd")
      |> mes("like to give you something.")
      |> next()
      |> mes("[Zabaroo]")
      |> mes("Ah, here we are. I found")
      |> mes("these while harvesting stones")
      |> mes("I was told that adventurers")
      |> mes("find these useful. Anyway,")
      |> mes("I hope you like these rocks...")
      |> set_char_var(:veins_stone, 8)

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 30_000, else: 300_000), 0)
    |> give_item(985, 3)
    |> close()
  end

  defp answer_questions(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Zabaroo]")
      |> mes("Wait, wait...")
      |> mes("Maybe I can answer")
      |> mes("a few of your questions")
      |> mes("before my body is wracked")
      |> mes("with throbbing pain. Let's...")
      |> mes("Let's at least give it a try.")
      |> next()
      |> select(["What's with these stones?", "Where's the old man?", "Nothing."])

    case choice do
      1 ->
        ctx
        |> mes("[Zabaroo]")
        |> mes("Well, we use these dark")
        |> mes("stones because they're")
        |> mes("pretty and easy to process.")
        |> mes("They're sort of a specialty")
        |> mes("of this town. I get paid to")
        |> mes("harvest these handy rocks.")
        |> next()
        |> mes("[Zabaroo]")
        |> mes("We can sell these to tourists,")
        |> mes("and we even have a factory")
        |> mes("that uses these stones.")
        |> mes("Still, it's not like the")
        |> mes("townspeople are getting")
        |> mes("rich off these stones.")
        |> next()
        |> mes("[Zabaroo]")
        |> mes("All of us are still")
        |> mes("barely making a living...")
        |> next()
        |> answer_questions()

      2 ->
        ctx
        |> mes("[Zabaroo]")
        |> mes("Absar? He's inside")
        |> mes("the Tool Shop. You")
        |> mes("can't miss him... Just")
        |> mes("look for the man with")
        |> mes("the crazy eyes!")
        |> next()
        |> answer_questions()

      3 ->
        ctx
        |> mes("[Zabaroo]")
        |> mes("Thanks for your help.")
        |> mes("If you can't find Absar")
        |> mes("in the Tool Shop, then")
        |> mes("you might want to stop")
        |> mes("by the Tavern. A-auuugh!")
        |> set_char_var(:veins_stone, 1)
        |> close()

      _ ->
        ctx
    end
  end
end
