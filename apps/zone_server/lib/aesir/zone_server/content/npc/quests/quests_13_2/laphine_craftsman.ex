defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.LaphineCraftsman do
  @moduledoc """
  The Laphine craftsman requests materials for Yai decorations.

  ## Behavior

  - Offers a repeatable collection quest and exchanges materials for experience and coins.
  - Explains Yai and checks the quest cooldown.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_in01",
        x: 97,
        y: 313,
        dir: 3,
        sprite: 446,
        name: "Laphine Craftsman",
        scope: :shared,
        unique_name: "Laphine Craftsman#ep13"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 2}]) == 0 do
      ctx
      |> mes("Wait a moment!!")
      |> mes("You have too many items.")
      |> mes("You can't receive this.")
      |> mes("Lighten your weight and")
      |> mes("try again.")
      |> close()
    else
      talk_when_ready(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_when_ready(ctx) do
    cond do
      is_equipped(ctx, 2782) != 1 or get_char_var(ctx, :ep13_2_rhea, 0) <= 99 ->
        ctx
        |> mes("[Laphine craftsman]")
        |> mes("Yur,Dur AnoVa?")
        |> mes("Wha? Dieb OsaDur .. ")
        |> mes("ah..RuffThus NeAsh. man nesAsh OdesAlah ?")
        |> close()

      get_char_var(ctx, :ep13_mdrama, 0) <= 5 ->
        ctx
        |> mes("[Laphine craftsman]")
        |> mes("Hm? Oh, can't you see I'm busy?")
        |> mes("I'm making ornaments though, if you must know.")
        |> close()

      true ->
        collection_quest(ctx)
    end
  end

  defp collection_quest(ctx) do
    ctx = set_local(ctx, :alba, checkquest(ctx, 7082))

    if get_local(ctx, :alba, 0) == 1 do
      cooldown(ctx)
    else
      ctx = set_local(ctx, :alba2, checkquest(ctx, 7081))

      if get_local(ctx, :alba2, 0) == 0 or get_local(ctx, :alba2, 0) == 1 do
        deliver_materials(ctx)
      else
        offer_help(ctx)
      end
    end
  end

  defp cooldown(ctx) do
    ctx = set_local(ctx, :time_chek, checkquest(ctx, 7082, :playtime))

    if get_local(ctx, :time_chek, 0) == 0 or get_local(ctx, :time_chek, 0) == 1 do
      ctx
      |> mes("[Laphine craftsman]")
      |> mes("Thank you for collecting those items for me.")
      |> mes("That should be sufficient for the time being.")
      |> close()
    else
      ctx
      |> mes("[Laphine craftsman]")
      |> mes("Thank you for collecting those items for me.")
      |> mes("Hopefully you can help us again.")
      |> erasequest(7082)
      |> close()
    end
  end

  defp deliver_materials(ctx) do
    if count_item(ctx, 7326) > 14 and count_item(ctx, 6075) > 14 do
      ctx
      |> mes("[Laphine craftsman]")
      |> mes("Oh, fantastic.")
      |> mes("These are enough materials for today.")
      |> mes("I'll let you know if I need more.")
      |> delitem(7326, 15)
      |> delitem(6075, 15)
      |> erasequest(7081)
      |> setquest(7082)
      |> getexp(30_000, 30_000)
      |> give_item(6081, 3)
      |> close()
    else
      ctx
      |> mes("[Laphine craftsman]")
      |> mes("What can I help you with?")
      |> mes("Not yet done with my request?")
      |> close()
    end
  end

  defp offer_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Laphine craftsman]")
      |> mes("What's up??")
      |> mes("I need to make more decorations for the Yai.")
      |> next()
      |> select(["May I help you?", "What's a Yai?"])

    if choice == 1 do
      request_materials(ctx)
    else
      explain_yai(ctx)
    end
  end

  defp request_materials(ctx) do
    {ctx, confirmation} =
      ctx
      |> mes("[Laphine craftsman]")
      |> mes("You want to help?")
      |> mes("This place is being used for battle but it is also our home.")
      |> next()
      |> mes("[Laphine craftsman]")
      |> mes("We prefer to be alone so we must each have our own Yai.")
      |> mes("Though we are in a military base we should take care of each Yai.")
      |> next()
      |> mes("[Laphine craftsman]")
      |> mes("I am not a soldier but we hope all of us to be as confident as they are.")
      |> mes("I would like to support all Laphine with my skills.")
      |> next()
      |> mes("[Laphine craftsman]")
      |> mes("So I want to help make decorations for everyone's Yai.")
      |> mes("I need more materials to make them.")
      |> next()
      |> mes("[Laphine craftsman]")
      |> mes("I heard that a water ghost has been appearing in the cave.")
      |> mes("Can you bring me 15 Crystallized Teardrop and 15 Fluorescent Liquid?")
      |> next()
      |> select(["Yes.", "Sorry."])

    if confirmation == 1 do
      ctx
      |> mes("[Laphine craftsman]")
      |> mes("Please take my request.")
      |> mes("Can you bring me 15 Crystallized Teardrop and 15 Fluorescent Liquid?")
      |> setquest(7081)
      |> close()
    else
      ctx
      |> mes("[Laphine craftsman]")
      |> mes("Yes, I'm sure that you have your own business to attend to.")
      |> mes("I feel embarrassed asking a favor from you, as a Laphine.")
      |> next()
      |> mes("[Laphine craftsman]")
      |> mes(
        "But, why are you trying to be involved in our business yet you won't take up our request?"
      )
      |> close()
    end
  end

  defp explain_yai(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Laphine craftsman]")
      |> mes("Yai...")
      |> mes("All grown Laphine have one.")
      |> mes("They're essential for all Laphine to live in since we are very private people.")
      |> next()
      |> select(["It's a house...?"])

    ctx
    |> mes("[Laphine craftsman]")
    |> mes("Yes...")
    |> mes("That's it. We sometimes invite our friends or guests to our Yai.")
    |> mes("And decorations for Yai are quite important to us...")
    |> next()
    |> mes("[Laphine craftsman]")
    |> mes("We Laphine care about ourselves and our Yai as well.")
    |> next()
    |> mes("[Laphine craftsman]")
    |> mes("We are far away from our hometown now...")
    |> mes("If we don't have this kind of hobby, there's nothing to enjoy here.")
    |> close()
  end
end
