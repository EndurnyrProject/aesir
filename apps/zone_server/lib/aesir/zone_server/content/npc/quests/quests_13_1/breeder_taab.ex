defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.BreederTaab do
  @moduledoc """
  Taab breeds the expedition's captured creatures and hires adventurers to gather their feed and bedding.

  ## Behavior

  - Explains the creature pens to expedition members and warns other visitors away.
  - Assigns one of five part-time gathering jobs while recruitment is open and slots remain.
  - Takes the requested supplies, awards mode-dependent experience, and starts the work cooldown.
  - Reminds workers of outstanding supplies or resets their job after the cooldown expires.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 143,
        y: 306,
        dir: 5,
        sprite: 946,
        name: "Breeder Taab",
        scope: :shared,
        unique_name: "Breeder Taab#ep13_alba"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) > 99 or get_char_var(ctx, :ep13_start, 0) > 99 do
      at_step(ctx, get_char_var(ctx, :ep13_alba, 0))
    else
      warns_away_visitors(ctx)
    end
  end

  defp at_step(ctx, step) do
    cond do
      step < 1 -> offers_assistance(ctx)
      step == 1 -> takes_fresh_fish(ctx)
      step == 2 -> takes_leaves_and_roots(ctx)
      step == 3 -> takes_monster_feed(ctx)
      step == 4 -> takes_meat(ctx)
      step == 5 -> takes_fur(ctx)
      step == 6 -> checks_work_cooldown(ctx)
      true -> ctx
    end
  end

  defp offers_assistance(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Taab]")
      |> mes("How may I help you?")
      |> next()
      |> select(["What is this place?", "I'm here for a job.", "No, thanks."])

    case choice do
      1 -> explains_the_pens(ctx)
      2 -> offers_work(ctx)
      3 -> warns_about_cages(ctx)
      _ -> ctx
    end
  end

  defp explains_the_pens(ctx) do
    ctx
    |> mes("[Taab]")
    |> mes("This is where we keep creatures")
    |> mes("captured here in Ash Vacuum.")
    |> mes("We study them to understand")
    |> mes("their characteristics and habits.")
    |> next()
    |> mes("[Taab]")
    |> mes("Of course, scholars and")
    |> mes("specialists perform the studies.")
    |> mes("I'm here to tame and breed")
    |> mes("dangerous monsters.")
    |> next()
    |> mes("[Taab]")
    |> mes("...I hope I can carry them")
    |> mes("around as my pets.")
    |> mes("Hillstions are so cute.")
    |> mes("You can't find such an")
    |> mes("animal on the mainland,")
    |> mes("you know?")
    |> close()
  end

  defp offers_work(ctx) do
    cond do
      get_server_temp_var(ctx, "PartTimeOn", 0) == 0 ->
        not_hiring(ctx)

      get_server_temp_var(ctx, "PartTimeSlots", 0) < 5 ->
        assigns_work(ctx)

      true ->
        no_jobs_left(ctx)
    end
  end

  defp not_hiring(ctx) do
    ctx
    |> mes("[Taab]")
    |> mes("I'm sorry, but I don't need any assistance right now.")
    |> mes("I'll make an official anouncement if I need help.")
    |> mes("Please come back then.")
    |> close()
  end

  defp no_jobs_left(ctx) do
    ctx
    |> mes("[Taab]")
    |> mes("Oh, I'm sorry, but no jobs are available right now.")
    |> mes("Some other part-timers finished all the work.")
    |> next()
    |> mes("[Taab]")
    |> mes("I'm sorry for the trouble I must have caused you to come here. Haha...")
    |> mes("I'll see you next time.")
    |> close()
  end

  defp assigns_work(ctx) do
    ctx =
      ctx
      |> set_server_temp_var(
        "PartTimeSlots",
        get_server_temp_var(ctx, "PartTimeSlots", 0) + 1
      )
      |> mes("[Taab]")
      |> mes("Welcome.")
      |> mes("Your job is simple:")
      |> mes("help me out by gathering")
      |> mes("the animals' feed or by")
      |> mes("cleaning their cages.")
      |> mes("These are the available jobs.")
      |> next()

    case get_server_temp_var(ctx, "PartTimeSlots", 0) do
      1 -> requests_fresh_fish(ctx)
      2 -> requests_leaves_and_roots(ctx)
      3 -> requests_monster_feed(ctx)
      4 -> requests_meat(ctx)
      _ -> requests_fur(ctx)
    end
  end

  defp requests_fresh_fish(ctx) do
    ctx
    |> set_char_var(:ep13_alba, 1)
    |> setquest(7042)
    |> mes("[Taab]")
    |> mes("Please bring me 50 Fresh Fish.")
    |> mes("They're feed for Tatachoes.")
    |> mes("I'm fresh out, and I'll need to restock very soon.")
    |> next()
    |> mes("[Taab]")
    |> mes("You can find them from Tatachoes in the fields.")
    |> mes("Strange, isn't it?")
    |> mes("I don't know where they've caught the fish.")
    |> next()
    |> mes("[Taab]")
    |> mes("Thank you in advance.")
    |> mes("Please bring me feed for Tatachoes: ^4d4dff50 Fresh Fish^000000.")
    |> close()
  end

  defp requests_leaves_and_roots(ctx) do
    ctx
    |> set_char_var(:ep13_alba, 2)
    |> setquest(7043)
    |> mes("[Taab]")
    |> mes("I've just run out of")
    |> mes("feed for Cornuses.")
    |> mes("Can you please bring me")
    |> mes("^4d4dff30 Great Leaves and 30 Brown Roots^000000?")
    |> next()
    |> mes("[Taab]")
    |> mes("You can find them from")
    |> mes("Pinguiculas in the fields.")
    |> mes("Thank you in advance.")
    |> close()
  end

  defp requests_monster_feed(ctx) do
    ctx
    |> set_char_var(:ep13_alba, 3)
    |> setquest(7044)
    |> mes("[Taab]")
    |> mes("I've just run out of")
    |> mes("feed for Hillsrions.")
    |> mes("Scholars think these")
    |> mes("guys are members")
    |> mes("of the cat family.")
    |> mes("I've been trying to feed")
    |> mes("them various things.")
    |> next()
    |> mes("[Taab]")
    |> mes("This time... I'd like to")
    |> mes("try Monster's Feed.")
    |> mes("Can you please bring me")
    |> mes("^4d4dff20 Monster's Feeds and 30 Pet Foods^000000?")
    |> next()
    |> mes("[Taab]")
    |> mes("Thank you in advance.")
    |> mes("Don't forget the")
    |> mes("20 Monster's Feeds")
    |> mes("and 30 Pet Foods.")
    |> mes("I hope the Hallsrions")
    |> mes("will like them.")
    |> close()
  end

  defp requests_meat(ctx) do
    ctx
    |> set_char_var(:ep13_alba, 4)
    |> setquest(7045)
    |> mes("[Taab]")
    |> mes("This is perfect because")
    |> mes("I was going to try some")
    |> mes("new feed for Hillsrions.")
    |> mes("I tried Monster's Feed,")
    |> mes("but I don't know if they")
    |> mes("liked it or not.")
    |> next()
    |> mes("[Taab]")
    |> mes("I want to try Meat this time.")
    |> mes("Can you please bring me")
    |> mes("^4d4dff50 Meat^000000 and ^4d4dff30 Pet Foods^000000?")
    |> next()
    |> mes("[Taab]")
    |> mes("Thank you in advance.")
    |> mes("Don't forget the")
    |> mes("^4d4dff50 Meat^000000 and ^4d4dff30 Pet Foods^000000")
    |> mes("I really hope they'll like the Meat.")
    |> close()
  end

  defp requests_fur(ctx) do
    ctx
    |> set_char_var(:ep13_alba, 5)
    |> setquest(7046)
    |> mes("[Taab]")
    |> mes("Oh, I always wanted to put something warm on the floor for my creatures.")
    |> mes("I was thinking of using fur.")
    |> mes("I can also use fur to cover the cage during rainy days, you know?")
    |> next()
    |> mes("[Taab]")
    |> mes("Can you please bring me ^4d4dff30 scraps of fur^000000?")
    |> mes("It sounds easy, doesn't it?")
    |> mes("I think the fur of Tatachoes and Hillsrions will be perfect.")
    |> next()
    |> mes("[Taab]")
    |> mes(
      "Of course, I'm not going to use them for the cages with the Tatachoes and Hillsrions."
    )
    |> mes("Those furs will be for the Cornuses.")
    |> next()
    |> mes("[Taab]")
    |> mes("It seems Cornuses love being warm.")
    |> mes(
      "The weather in this area is so strange that I'm having a hard time optimizing the temperature for each kind of creature."
    )
    |> next()
    |> mes("[Taab]")
    |> mes("Thank you in advance.")
    |> mes("Don't forget the 30 scraps of fur.")
    |> close()
  end

  defp warns_about_cages(ctx) do
    ctx
    |> mes("[Taab]")
    |> mes("Please stay far away from the cages.")
    |> mes("Sometimes, the creatures try to escape their cages.")
    |> close()
  end

  defp takes_fresh_fish(ctx) do
    if count_item(ctx, 579) > 49 do
      ctx
      |> mes("[Taab]")
      |> mes("Oh, thanks!")
      |> mes("You brought them their food!")
      |> mes("Just in time too: they look")
      |> mes("like they're ready to chow down.")
      |> mes("The Tatachoes will love these.")
      |> next()
      |> offers_spiritual_reward()
      |> delitem(579, 50)
      |> set_char_var(:ep13_alba, 6)
      |> rewards_feed_work()
      |> erasequest(7042)
      |> setquest(7047)
      |> close()
    else
      ctx
      |> mes("[Taab]")
      |> mes("Please bring me 50 Fresh Fish for Tatachoes.")
      |> mes("You should hurry up because they get impatient when they're hungry.")
      |> close()
    end
  end

  defp takes_leaves_and_roots(ctx) do
    if count_item(ctx, 7198) > 29 and count_item(ctx, 7188) > 29 do
      ctx
      |> mes("[Taab]")
      |> mes("Oh, thanks!")
      |> mes("You brought them their food!")
      |> mes("Just in time too: they look")
      |> mes("like they're ready to chow down.")
      |> mes("The Cornus will love these.")
      |> next()
      |> offers_spiritual_reward()
      |> delitem(7198, 30)
      |> delitem(7188, 30)
      |> set_char_var(:ep13_alba, 6)
      |> rewards_cornus_work()
      |> erasequest(7043)
      |> setquest(7047)
      |> close()
    else
      ctx
      |> mes("[Taab]")
      |> mes("Don't forget the 30 Great")
      |> mes("Leaves and 30 Brown Roots.")
      |> mes("I need to stock as much")
      |> mes("of them as possible")
      |> mes("because the Cornuses")
      |> mes("get hungry quite often.")
      |> close()
    end
  end

  defp takes_monster_feed(ctx) do
    if count_item(ctx, 528) > 19 and count_item(ctx, 537) > 29 do
      ctx
      |> mes("[Taab]")
      |> mes("Oh, thanks!")
      |> mes("You brought them their")
      |> mes("food! Just in time too,")
      |> mes("they look like they're")
      |> mes("ready to chow down.")
      |> mes("The Hillsrions will love these.")
      |> next()
      |> offers_spiritual_reward()
      |> delitem(528, 20)
      |> delitem(537, 30)
      |> set_char_var(:ep13_alba, 6)
      |> rewards_feed_work()
      |> erasequest(7044)
      |> setquest(7047)
      |> close()
    else
      ctx
      |> mes("[Taab]")
      |> mes("Don't forget the")
      |> mes("20 Monster's Feeds")
      |> mes("and 30 Pet Foods.")
      |> mes("They're for the Hillsrions.")
      |> close()
    end
  end

  defp takes_meat(ctx) do
    if count_item(ctx, 517) > 49 and count_item(ctx, 537) > 29 do
      ctx
      |> mes("Oh, thanks!")
      |> mes("You brought them their")
      |> mes("food! Just in time too,")
      |> mes("they look like they're")
      |> mes("ready to chow down.")
      |> mes("The Hillsrions will love these.")
      |> next()
      |> offers_spiritual_reward()
      |> delitem(517, 50)
      |> delitem(537, 30)
      |> set_char_var(:ep13_alba, 6)
      |> rewards_feed_work()
      |> erasequest(7045)
      |> setquest(7047)
      |> close()
    else
      ctx
      |> mes("[Taab]")
      |> mes("Don't forget the")
      |> mes("50 Meat and")
      |> mes("30 Pet Foods.")
      |> mes("They're for the Hillsrions.")
      |> close()
    end
  end

  defp takes_fur(ctx) do
    if count_item(ctx, 6020) > 29 do
      ctx
      |> mes("[Taab]")
      |> mes("Oh, thanks!")
      |> mes("You brought me the Furs!")
      |> mes("Just in time too!")
      |> next()
      |> offers_spiritual_reward()
      |> delitem(6020, 30)
      |> set_char_var(:ep13_alba, 6)
      |> rewards_feed_work()
      |> erasequest(7046)
      |> setquest(7047)
      |> close()
    else
      ctx
      |> mes("[Taab]")
      |> mes("Don't forget the")
      |> mes("30 Furs. They're for the Cornus' cage.")
      |> close()
    end
  end

  defp offers_spiritual_reward(ctx) do
    ctx
    |> mes("[Taab]")
    |> mes("I really want to give you")
    |> mes("something in return...")
    |> mes("But I have nothing")
    |> mes("material to give you.")
    |> mes("How about a spiritual reward?")
    |> next()
  end

  defp rewards_feed_work(ctx) do
    if Rathena.truthy?(checkre(ctx, 3)) do
      ctx
      |> getexp(8000, 3000)
      |> mes("^4d4dff You have received 8,000 EXP")
      |> mes("and 3,000 JEXP.^000000.")
    else
      ctx
      |> getexp(80_000, 30_000)
      |> mes("^4d4dff You have received 80,000 EXP")
      |> mes("and 30,000 JEXP.^000000.")
    end
  end

  defp rewards_cornus_work(ctx) do
    if Rathena.truthy?(checkre(ctx, 3)) do
      ctx
      |> getexp(9000, 4000)
      |> mes("^4d4dff You have received 9,000 EXP")
      |> mes("and 4,000 JEXP.^000000.")
    else
      ctx
      |> getexp(90_000, 40_000)
      |> mes("^4d4dff You have received 90,000 EXP")
      |> mes("and 40,000 JEXP.^000000.")
    end
  end

  defp checks_work_cooldown(ctx) do
    ctx = set_local(ctx, :alba_check, checkquest(ctx, 7047, :playtime))

    case get_local(ctx, :alba_check, 0) do
      -1 -> resets_work(ctx)
      0 -> suggests_rest(ctx)
      1 -> suggests_rest(ctx)
      2 -> resets_work(ctx)
      _ -> ctx
    end
  end

  defp resets_work(ctx) do
    ctx
    |> mes("[Taab]")
    |> mes("Thank you for")
    |> mes("helping me last time.")
    |> mes("We have a constant")
    |> mes("flow of part-time work.")
    |> mes("I hope you'll come by")
    |> mes("to help me again.")
    |> erasequest(7047)
    |> set_char_var(:ep13_alba, 0)
    |> close()
  end

  defp suggests_rest(ctx) do
    ctx =
      ctx
      |> mes("[Taab]")
      |> mes("I've got enough feed")
      |> mes("and supplies to last a while.")
      |> mes("Thank you for your")
      |> mes("help last time.")
      |> next()
      |> mes("[Taab]")
      |> mes("I don't think I need")
      |> mes("any assistance for now...")

    ctx
    |> mes("#{char_name(ctx, 0)},")
    |> mes("why don't you go rest?")
    |> close()
  end

  defp warns_away_visitors(ctx) do
    ctx
    |> mes("[Taab]")
    |> mes("Please step aside! It's dangerous")
    |> mes("to get too close to those")
    |> mes("creatures. You don't look like a")
    |> mes("member of the expedition.")
    |> mes("I guess you're not allowed")
    |> mes("to be here. Please leave.")
    |> close()
  end
end
