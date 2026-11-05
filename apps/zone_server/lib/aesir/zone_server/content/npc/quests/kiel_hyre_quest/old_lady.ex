defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.OldLady do
  @moduledoc """
  An old friend of Allysia lends the Rosimier Mansion key and explains her past.

  ## Behavior

  - Lends the mansion key after recounting Allysia and James Rosimier's history.
  - Collects the key once the four mansion clues are present and directs the adventurer to the fisherman.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 250,
        y: 132,
        dir: 0,
        sprite: 711,
        name: "Old Lady",
        scope: :shared,
        unique_name: "Old Lady#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 56 ->
        ctx
        |> mes("[Old Lady]")
        |> mes("Oooh, my legs and back")
        |> mes("are so sore. These old")
        |> mes("bones ache all over...")
        |> close()

      quest_stage == 56 ->
        offer_mansion_key(ctx)

      (quest_stage == 58 and count_item(ctx, 7499) < 1) or
        count_item(ctx, 7500) < 1 or count_item(ctx, 7501) < 1 or count_item(ctx, 7502) < 1 ->
        ctx
        |> mes("[Old Lady]")
        |> mes("Please hurry and find")
        |> mes("whatever you're searching")
        |> mes("for in the Rosimier Mansion.")
        |> mes("I might get in trouble if")
        |> mes("the people from City Hall")
        |> mes("come and ask me for the key...")
        |> close()

      quest_stage == 58 and count_item(ctx, 7499) == 1 and count_item(ctx, 7500) == 1 and
        count_item(ctx, 7501) == 1 and count_item(ctx, 7502) == 1 ->
        return_mansion_key(ctx)

      quest_stage >= 60 ->
        ctx
        |> mes("[Old Lady]")
        |> mes("Yep, Rain's coming.")
        |> mes("Can feel it in my bones.")
        |> close()

      true ->
        ctx
    end
  end

  defp offer_mansion_key(ctx) do
    if checkweight(ctx, [{7498, 1}]) == 0 do
      ctx
      |> mes("^3355FFJust a second...")
      |> mes("You're carrying too")
      |> mes("many items with you")
      |> mes("right now, so you'll")
      |> mes("need to free up more")
      |> mes("Inventory space first...^000000")
      |> close()
    else
      ask_about_allysia(ctx)
    end
  end

  defp ask_about_allysia(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Old Lady]")
      |> mes("Goodness, I hate this")
      |> mes("weather! Reminds me")
      |> mes("of how old I've gotten!")
      |> mes("It chills my bones, it does!")
      |> next()
      |> select(["......", "Do you know that grandma?"])

    case choice do
      1 ->
        ctx
        |> mes("[Old Lady]")
        |> mes("Damn it! If only I didn't")
        |> mes("have all those adventures")
        |> mes("in my youth! Then maybe")
        |> mes("I wouldn't suffer so in")
        |> mes("my advanced age!")
        |> close()

      2 ->
        explain_allysias_past(ctx)

      _ ->
        ctx
    end
  end

  defp explain_allysias_past(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Old Lady]")
      |> mes("Oh... Yes. She was")
      |> mes("the mother of my best")
      |> mes("friend, ^3355FFAllysia^000000. Ever since")
      |> mes("she commited suicide, things")
      |> mes("haven't been the same. Her")
      |> mes("mother lost her sanity...")
      |> next()
      |> select(["Was ^3355FFAllysia^000000...?"])

    {ctx, _} =
      ctx
      |> mes("[Old Lady]")
      |> mes("Oh, Allysia was such")
      |> mes("a beautiful girl. So many")
      |> mes("men wanted her, especially")
      |> mes("that dashing James Rosimier.")
      |> mes("I remember hearing that they")
      |> mes("were going to get married...")
      |> next()
      |> mes("[Old Lady]")
      |> mes("I was so happy for her!")
      |> mes("But then, all of a sudden,")
      |> mes("she killed herself. Well,")
      |> mes("that's what they all say.")
      |> mes("Even today, I'm still not")
      |> mes("sure what happened.")
      |> next()
      |> select(["Wait, who's James Rosimier?"])

    {ctx, _} =
      ctx
      |> mes("[Old Lady]")
      |> mes("Oh, James belonged to")
      |> mes("one of the oldest and richest")
      |> mes("families in Juno. Everything")
      |> mes("was going great for them, but")
      |> mes("some time after Allysia died,")
      |> mes("the family went bankrupt.")
      |> next()
      |> mes("[Old Lady]")
      |> mes("The city manages their")
      |> mes("old residence now. For")
      |> mes("some reason, they decided")
      |> mes("to entrust me with the master")
      |> mes("key to the Rosimier Mansion.")
      |> next()
      |> select(["May I borrow the Master Key?"])

    ctx
    |> mes("[Old Lady]")
    |> mes("Well, I'm really not")
    |> mes("supposed to give it to just")
    |> mes("anyone, but I can tell that")
    |> mes("you're working with Allysia's")
    |> mes("best interests at heart.")
    |> next()
    |> mes("[Old Lady]")
    |> mes("However, you've got to")
    |> mes("make sure that you return")
    |> mes("it to me before the people")
    |> mes("from City Hall ask me for it.")
    |> mes("Alright then, I hope you find")
    |> mes("what you're looking for.")
    |> give_item(7498, 1)
    |> set_char_var(:KielHyreQuest, 58)
    |> close()
  end

  defp return_mansion_key(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Old Lady]")
      |> mes("Oh, you're finished")
      |> mes("searching the mansion?")
      |> mes("Depressing, isn't it?")
      |> mes("The creditors basically")
      |> mes("ransacked everything")
      |> mes("a very long time ago.")
      |> next()
      |> select(["Why did ^3355FFAllysia^000000...?"])

    ctx
    |> mes("[Old Lady]")
    |> mes("Well, I know that James")
    |> mes("and Allysia were in love,")
    |> mes("and he promised to marry")
    |> mes("her. Now, supposedly his")
    |> mes("family already betrothed")
    |> mes("him to another woman.")
    |> next()
    |> mes("[Old Lady]")
    |> mes("Time went by, and he")
    |> mes("was forced to marry his")
    |> mes("fiancee. Allysia was pretty")
    |> mes("devastated. I think maybe")
    |> mes("that's what she... you know...")
    |> next()
    |> mes("[Old Lady]")
    |> mes("Listen, if you want to learn")
    |> mes("more about what happened,")
    |> mes("then I think you should talk")
    |> mes("to the ^3355FFfisherman that lives^000000")
    |> mes("^3355FFsouth of the Kiel Hyre Academy.^000000")
    |> next()
    |> mes("[Old Lady]")
    |> mes("He's the one that found")
    |> mes("Allysia's body in the river,")
    |> mes("so he might have a better")
    |> mes("idea of what had happened.")
    |> delitem(7498, 1)
    |> set_char_var(:KielHyreQuest, 60)
    |> close()
  end
end
