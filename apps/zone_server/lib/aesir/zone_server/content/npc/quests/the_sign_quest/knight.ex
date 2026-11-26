defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Knight do
  @moduledoc """
  Leibech collects unusual goods and awaits a delivery from the Alchesh Trading Company.

  ## Behavior

  - Discusses his collection and asks about his missing order.
  - Accepts the correctly marked delivery, gives a receipt and awards experience.

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
        map: "yuno",
        x: 330,
        y: 100,
        dir: 4,
        sprite: 734,
        name: "Knight",
        scope: :shared,
        unique_name: "Knight#ss"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Leibech]")
    progress = get_char_var(ctx, :sign_q, 0)

    cond do
      progress < 38 or progress == 97 ->
        collection(ctx)

      progress == 38 ->
        if count_item(ctx, 7049) < 1, do: missing_order(ctx), else: check_order(ctx)

      progress == 98 ->
        ctx
        |> mes("I am interested in collecting uncommon stuffs.")
        |> mes("For that, I need to find something that I cannot see around here.")
        |> next()
        |> mes("[Leibech]")
        |> mes("Usually, I am using Alchesh Trading Company for that.")
        |> mes("Although the price is little bit higher than I wish,")
        |> mes("they are very reliable.")
        |> close()

      true ->
        ctx
        |> mes("Hey, thanks for")
        |> mes("delivering my order")
        |> mes("for me. It was a great")
        |> mes("addition to my collection!")
        |> next()
        |> mes("[Leibech]")
        |> mes("It's really tough to")
        |> mes("find unique and oddball")
        |> mes("items, but I find great pride")
        |> mes("in expanding my collection~")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp collection(ctx) do
    ctx
    |> mes("I have a great")
    |> mes("interest in collecting")
    |> mes("unique and uncommon")
    |> mes("goods. You know, things")
    |> mes("that most people see just")
    |> mes("once in their lifetimes.")
    |> next()
    |> mes("[Leibech]")
    |> mes("I usually use the")
    |> mes("Alchesh Trading Company")
    |> mes("to help add to my collection.")
    |> mes("Their prices aren't the cheapest, but their service is very reliable.")
    |> close()
  end

  defp missing_order(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Excuse me...")
      |> mes("Are you from the Alchesh")
      |> mes("Trading Company? I've been")
      |> mes("waiting for my order and they")
      |> next()
      |> select(["No, I'm not.", "They must be busy.", "Yes, I have your order."])

    case choice do
      1 ->
        ctx
        |> mes("[Leibech]")
        |> mes("Oh, I'm sorry.")
        |> mes("My mistake. Well")
        |> mes("then, be safe in")
        |> mes("your travels.")
        |> close()

      2 ->
        ctx
        |> mes("[Leibech]")
        |> mes("I suppose you're")
        |> mes("right. I mean, Juno")
        |> mes("is pretty far from")
        |> mes("Alberta. Maybe I'm")
        |> mes("just overly excited")
        |> mes("about my delivery...")
        |> close()

      3 ->
        ask_order_location(ctx)

      _ ->
        ctx
    end
  end

  defp ask_order_location(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Leibech]")
      |> mes("Really?!")
      |> mes("That's great!")
      |> mes("Do you have the")
      |> mes("item I ordered?")
      |> mes("Where is it?")
      |> next()
      |> select(["I put it somewhere.", "Sorry, I lost it."])

    case choice do
      1 ->
        ctx
        |> mes("[Leibech]")
        |> mes("Oh, alright. ")
        |> mes("So long as you didn't")
        |> mes("lose it, that's fine. I'll wait")
        |> mes("here, so would you bring it")
        |> mes("to me as soon as you can?")
        |> close()

      2 ->
        lost_order(ctx)

      _ ->
        ctx
    end
  end

  defp lost_order(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Leibech]")
      |> mes("What...?")
      |> mes("Hey, man.")
      |> mes("That's not funny!")
      |> mes("You're joking, right?")
      |> next()
      |> select(["No. I'm not joking.", "Okay, you got me~"])

    case choice do
      1 ->
        ctx
        |> mes("[Leibech]")
        |> mes("I don't believe it!")
        |> mes("I think I'm going to")
        |> mes("write a letter to your")
        |> mes("boss, Mister Bakerlan.")
        |> mes("What do you think ")
        |> mes("about that?")
        |> close()

      2 ->
        ctx
        |> mes("[Leibech]")
        |> mes("Oh, thank goodness!")
        |> mes("I thought you might have")
        |> mes("really lost it! Say, would you")
        |> mes("bring it to me as soon as")
        |> mes("can? I'll wait for you here.")
        |> close()

      _ ->
        ctx
    end
  end

  defp check_order(ctx) do
    ctx = set_local(ctx, :signid, getcharid(ctx, 0))
    ctx = set_local(ctx, :sign3, :erlang.band(get_local(ctx, :signid, 0), 65_535))

    ctx =
      ctx
      |> set_local(:sign4, :erlang.bsr(get_local(ctx, :signid, 0), 16))
      |> set_local(:sign1, 254)
      |> set_local(:sign2, 0)

    if Rathena.truthy?(
         countitem2(
           ctx,
           7049,
           1,
           0,
           0,
           get_local(ctx, :sign1, 0),
           get_local(ctx, :sign2, 0),
           get_local(ctx, :sign3, 0),
           get_local(ctx, :sign4, 0)
         )
       ) do
      complete_order(ctx)
    else
      ctx
      |> mes("Hm...?")
      |> mes("There must be some")
      |> mes("mistake. This isn't what")
      |> mes("I ordered. Well, I can wait... ")
      |> next()
      |> mes("[Leibech]")
      |> mes("Just come back and")
      |> mes("bring me what I actually")
      |> mes("ordered, alright? And this")
      |> mes("time, don't make any mistakes.")
      |> mes("Thanks, I appreciate it~")
      |> close()
    end
  end

  defp complete_order(ctx) do
    ctx =
      ctx
      |> mes("Finally, it's here!")
      |> mes("Yes, this is what I ordered.")
      |> mes("Thanks for the delivery!")
      |> next()
      |> mes("[Leibech]")
      |> mes("Well, here's your")
      |> mes("receipt. Please take")
      |> mes("this to Mister Bakerlan")
      |> mes("so he knows you did")
      |> mes("a good job for me.")
      |> mes("Thanks again!")

    ctx =
      ctx
      |> delitem2(
        7049,
        1,
        1,
        0,
        0,
        get_local(ctx, :sign1, 0),
        get_local(ctx, :sign2, 0),
        get_local(ctx, :sign3, 0),
        get_local(ctx, :sign4, 0)
      )
      |> set_char_var(:sign_q, 39)
      |> give_item(7181, 1)

    renewal = Rathena.truthy?(checkre(ctx, 3))

    experience =
      cond do
        base_level(ctx) < 60 -> 100
        base_level(ctx) < 70 -> 200
        base_level(ctx) < 80 -> 400
        base_level(ctx) < 90 -> 700
        true -> 1100
      end

    experience = if renewal, do: experience, else: experience * 10

    ctx
    |> getexp(experience, 0)
    |> close()
  end
end
