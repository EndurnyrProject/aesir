defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.FerociousGorurug do
  @moduledoc """
  Ferocious Gorurug, the fishing cat who trades ten Pieces of Fish for a day's expedition
  experience.

  ## Behavior

  - Below four Cat Trading Points only watches the water; at four teaches how to fish and sets
    the credit to 5.
  - From five points on takes ten Pieces of Fish for 15,000 experience and one credit each time,
    restarting quest 12060. Each credit band (5-19, 20-39, 40-59, 60 and above) has its own idle
    line when the player brings too few, and the last band also casts a skill and quotes the
    reference's 1,500 experience line.
  - While the fishing quest's playtime is running it is off duty, and once the playtime lapses it
    clears the quest for a new day.

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
        x: 69,
        y: 144,
        dir: 0,
        sprite: 421,
        name: "Ferocious Gorurug",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @fishing_quest 12060
  @piece_of_fish 6039
  @fish_per_delivery 10

  @renewal_exp 20_000
  @pre_renewal_exp 30_000
  @daily_exp 15_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case checkquest(ctx, @fishing_quest, :playtime) do
      -1 -> fishing_lesson(ctx)
      0 -> off_duty(ctx)
      1 -> off_duty(ctx)
      _lapsed -> new_day(ctx)
    end
  end

  defp fishing_lesson(ctx) do
    case get_char_var(ctx, :ep13_yong1, 0) do
      credit when credit < 4 ->
        watching_the_water(ctx)

      4 ->
        teaches_fishing(ctx)

      5 ->
        first_delivery(ctx)

      credit when credit < 20 ->
        turn_in_fish(ctx, "^0000ffYou gain EXP 15,000^000000", &fish_again/1)

      credit when credit < 40 ->
        turn_in_fish(ctx, "^0000ffYou gain EXP 15,000^000000", &waiting_for_you/1)

      credit when credit < 60 ->
        turn_in_fish(ctx, "^0000ffYou gain EXP 15,000^000000", &happy_to_see_you/1)

      _credit ->
        purring_welcome(ctx)
    end
  end

  defp watching_the_water(ctx) do
    ctx
    |> mes("[Ferocious Gorurug]")
    |> mes("Grrr....")
    |> next()
    |> mes("A cat purring like a lion")
    |> mes("is looking into the water.")
    |> close()
  end

  defp teaches_fishing(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Ferocious Gorurug]")
      |> mes("I'm busy.")
      |> mes("I need to catch fish.")
      |> next()
      |> select(["Gyaruk has sent me."])

    {ctx, _} =
      ctx
      |> mes("[Ferocious Gorurug]")
      |> mes("Gyaruk sent you?")
      |> mes("Oh, you are here to fish? *Purr*")
      |> next()
      |> select(["What should I do?"])

    ctx
    |> mes("[Ferocious Gorurug]")
    |> mes("You need to catch fish. There are schools of fish in the waters.")
    |> mes(
      "It's hard to see them but if you use your cursor to click around, you should be able to catch them."
    )
    |> next()
    |> mes("[Ferocious Gorurug]")
    |> mes("It's easier to fish in the water outside the town.")
    |> mes("If you're not afraid of monsters, you can go fishing over there.")
    |> mes("*Purr*")
    |> next()
    |> mes("[Ferocious Gorurug]")
    |> mes("Now, let me teach you how to fish.")
    |> mes("It's simple: bring your cursor to a school of fish, and then click it to grab them.")
    |> next()
    |> mes("[Ferocious Gorurug]")
    |> mes("You'll have a hard time to catch them at first, but you'll get better.")
    |> mes("It gets easier with a bit of practice.")
    |> set_char_var(:ep13_yong1, 5)
    |> close()
  end

  # The very first delivery pays the mode's experience instead of the daily 15,000 and lifts
  # the credit straight to 10.
  defp first_delivery(ctx) do
    if count_item(ctx, @piece_of_fish) > @fish_per_delivery - 1 do
      renewal? = Rathena.truthy?(checkre(ctx, 3))
      exp = if renewal?, do: @renewal_exp, else: @pre_renewal_exp

      exp_text =
        if renewal?,
          do: "^0000ffYou gain EXP 20,000^000000",
          else: "^0000ffYou gain EXP 30,000^000000"

      ctx
      |> mes("[Ferocious Gorurug]")
      |> mes("You've brough Pieces of Fish!")
      |> mes("GOOD JOB!")
      |> delitem(@piece_of_fish, @fish_per_delivery)
      |> getexp(exp, 0)
      |> set_char_var(:ep13_yong1, 10)
      |> setquest(@fishing_quest)
      |> next()
      |> mes(exp_text)
      |> close()
    else
      ctx
      |> mes("[Ferocious Gorurug]")
      |> mes("Bring your cursor to a school of fish, then click it to grab them.")
      |> mes("Don't move while doing it!")
      |> close()
    end
  end

  defp purring_welcome(ctx) do
    ctx = npcskill(ctx, 28, 8, 50, 50)

    turn_in_fish(ctx, "^0000ffYou gain EXP 1,500^000000", &welcomes_you/1)
  end

  # Every band hands over the same ten fish for the same experience; only the idle dialog and
  # the experience line differ.
  defp turn_in_fish(ctx, exp_text, idle) do
    if count_item(ctx, @piece_of_fish) > @fish_per_delivery - 1 do
      ctx
      |> mes("[Ferocious Gorurug]")
      |> mes("You've brough Pieces of Fish!")
      |> mes("GOOD JOB!")
      |> delitem(@piece_of_fish, @fish_per_delivery)
      |> getexp(@daily_exp, 0)
      |> setquest(@fishing_quest)
      |> set_char_var(:ep13_yong1, get_char_var(ctx, :ep13_yong1, 0) + 1)
      |> next()
      |> mes(exp_text)
      |> close()
    else
      idle.(ctx)
    end
  end

  defp fish_again(ctx) do
    ctx
    |> mes("[Ferocious Gorurug]")
    |> mes("Do you want to fish again?")
    |> mes("Don't forget to bring me")
    |> mes("Pieces of Fish if you catch them.")
    |> close()
  end

  defp waiting_for_you(ctx) do
    ctx
    |> mes("[Ferocious Gorurug]")
    |> mes("Hey, I've been waiting for you!")
    |> mes("Good luck fishing today!")
    |> close()
  end

  defp happy_to_see_you(ctx) do
    ctx
    |> mes("Gorurug looks happy to see you.")
    |> next()
    |> mes("[Ferocious Gorurug]")
    |> mes("What do you want to catch today? *Purr*")
    |> close()
  end

  defp welcomes_you(ctx) do
    ctx
    |> mes("Gorurung welcomes you with a happy purr.")
    |> next()
    |> mes("[Ferocious Gorurug]")
    |> mes("Welcome!")
    |> mes("You're here to give me fishes, aren't you?")
    |> close()
  end

  defp off_duty(ctx) do
    ctx
    |> mes("[Ferocious Gorurug]")
    |> mes("*Yawn*")
    |> mes("I'm sorry, but I'm off-duty.")
    |> mes("I can't accept any fish right now.")
    |> mes("Come back tomorrow, alright?")
    |> close()
  end

  defp new_day(ctx) do
    ctx
    |> erasequest(@fishing_quest)
    |> mes("[Ferocious Gorurug]")
    |> mes("*Purr*")
    |> mes("Another day has started, back to work!")
    |> mes("You can now bring me fish if you catch them.")
    |> close()
  end
end
