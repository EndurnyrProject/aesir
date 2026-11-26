defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.DanceInstructor do
  @moduledoc """
  Offers a megaphone in exchange for escorting dancers and paying a fee.

  ## Behavior

  - Guides the player through the escort and sells replacement megaphones.

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
      %{
        map: "job_duncer",
        x: 93,
        y: 106,
        dir: 6,
        sprite: 892,
        name: "Dance Instructor",
        scope: :shared,
        unique_name: "Dance Instructor#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("^3355FFWait a second!")
      |> mes("Right now, you're carrying")
      |> mes("too many things with you.")
      |> mes("Please come back after")
      |> mes("using the Kafra Service")
      |> mes("to store some of your items.^000000")
      |> close()
    else
      dance_quest(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp dance_quest(ctx) do
    quest = get_char_var(ctx, :que_sch, 0)

    cond do
      quest < 11 ->
        ctx
        |> mes("[Hianna]")
        |> mes("Keep up the good work,")
        |> mes("everyone! There's only")
        |> mes("a few days left until the")
        |> mes("big performance! Hey...")
        |> mes("You! Can't you do it right?")
        |> mes("Turn your waist quicker!")
        |> close()

      quest == 11 ->
        offer_escort(ctx)

      quest < 17 ->
        ctx
        |> mes("[Hianna]")
        |> mes("What are you still doing")
        |> mes("here? Shouldn't you be")
        |> mes("escorting the Dancers to")
        |> mes("the Schwaltvalt Republic")
        |> mes("already? Get a move on~")
        |> close()

      quest == 17 ->
        collect_fee(ctx)

      quest == 18 ->
        offer_replacement(ctx)

      true ->
        ctx
        |> mes("[Hianna]")
        |> mes("Trust me, we've made")
        |> mes("good use of the money")
        |> mes("that you've ''donated.''")
        |> mes("Thanks for taking good")
        |> mes("care of my Dancers~")
        |> close()
    end
  end

  defp offer_escort(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hianna]")
      |> mes("Hey, who are you?")
      |> mes("We already have enough")
      |> mes("problems with too many")
      |> mes("pervs ogling the Dancers.")
      |> mes("I'd prefer it if you didn't")
      |> mes("come to watch us practice.")
      |> next()
      |> select(["I want a Megaphone.", "Eeek..."])

    if choice == 2 do
      ctx
      |> mes("[Hianna]")
      |> mes("If you really want to")
      |> mes("watch us dance, come to")
      |> mes("the show and buy a ticket.")
      |> mes("Watching for free isn't")
      |> mes("exactly supporting the arts.")
      |> close()
    else
      request_escort(ctx)
    end
  end

  defp request_escort(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hianna]")
      |> mes("You want a Megaphone?")
      |> mes("Well, I'm sorry, but it's")
      |> mes("not just something I can")
      |> mes("lend to anybody. Then again")
      |> mes("it's not like you can find one")
      |> mes("anywhere else, either.")
      |> next()
      |> select(["Please! I'll do anything!", "Later."])

    if choice == 2 do
      ctx
      |> mes("[Hianna]")
      |> mes("Alright, then.")
      |> mes("I'm sorry that")
      |> mes("I can't help you.")
      |> close()
    else
      explain_escort(ctx)
    end
  end

  defp explain_escort(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hianna]")
      |> mes("Anything, huh?")
      |> mes("Well, you just said")
      |> mes("the magic word. Listen")
      |> mes("carefully to what I want")
      |> mes("you to do for me.")
      |> next()
      |> select(["Listen", "Reconsider"])

    if choice == 1 do
      confirm_escort(ctx)
    else
      ctx
      |> mes("[Hianna]")
      |> mes("Alright, take your")
      |> mes("time. I'm in no rush.")
      |> close()
    end
  end

  defp confirm_escort(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hianna]")
      |> mes("First, I want a little")
      |> mes("cash. Consider it a rental")
      |> mes("fee. 500,000 zeny should be")
      |> mes("just about enough. Then,")
      |> mes("I want you to do me a favor.")
      |> next()
      |> mes("[Hianna]")
      |> mes("The Schwarzwald Republic")
      |> mes("requested me to send some")
      |> mes("Dancers for some party, but")
      |> mes("I don't have enough guards")
      |> mes("to protect them on their")
      |> mes("way over there.")
      |> next()
      |> mes("[Hianna]")
      |> mes("If you act as bodyguard")
      |> mes("to my Dancers on the way")
      |> mes("to the Schwarzwald Republic,")
      |> mes("I'll lend you my Megaphone")
      |> mes("once you come back. So...")
      |> mes("How does that sound?")
      |> next()
      |> select(["Sounds good.", "Like a ripoff."])

    if choice == 1 do
      ctx
      |> mes("[Hianna]")
      |> mes("I'm glad you agree~")
      |> mes("Okay, the Dancers are")
      |> mes("waiting are the entrance,")
      |> mes("so bring them over to the")
      |> mes("Schwarzwald Republic as")
      |> mes("soon as you're ready.")
      |> set_char_var(:que_sch, 12)
      |> close()
    else
      ctx
      |> mes("[Hianna]")
      |> mes("So... I guess you")
      |> mes("didn't need that")
      |> mes("Megaphone as")
      |> mes("badly as I thought.")
      |> close()
    end
  end

  defp collect_fee(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hianna]")
      |> mes("Thanks for all your")
      |> mes("hard work. The Dancers")
      |> mes("told me that you did a good")
      |> mes("job escorting them. Now...")
      |> mes("Do you have the money?")
      |> next()
      |> select(["Yes", "No"])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Hianna]")
        |> mes("I can't have you breaking")
        |> mes("your promises, so I won't")
        |> mes("give you the Megaphone")
        |> mes("until you pay me the")
        |> mes("500,000 zeny that you")
        |> mes("said that you would.")
        |> close()

      zeny(ctx) < 500_000 ->
        ctx
        |> mes("[Hianna]")
        |> mes("What's this? Hmm...")
        |> mes("I think you made a mistake.")
        |> mes("This isn't enough money.")
        |> mes("Remember, 500,000 zeny~")
        |> close()

      true ->
        ctx
        |> mes("[Hianna]")
        |> mes("Perfect. Well, here's")
        |> mes("your Megaphone. Thanks")
        |> mes("for everything, and I'll see")
        |> mes("you around, adventurer~")
        |> pay_zeny(500_000)
        |> set_char_var(:que_sch, 18)
        |> give_item(7040, 1)
        |> close()
    end
  end

  defp offer_replacement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hianna]")
      |> mes("Thanks for escorting")
      |> mes("my Dancers over to the")
      |> mes("Schwarzwald Republic.")
      |> mes("Anything I can help")
      |> mes("you with today?")
      |> next()
      |> select(["I'd like another Megaphone.", "No thanks."])

    if choice == 1 do
      confirm_replacement(ctx)
    else
      farewell(ctx)
    end
  end

  defp confirm_replacement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hianna]")
      |> mes("Well, I guess I can let")
      |> mes("you have another one if")
      |> mes("you pay me 500,000 zeny.")
      |> mes("You sure you want to pay")
      |> mes("the money for a Megaphone?")
      |> next()
      |> select(["Yes", "No"])

    cond do
      choice != 1 ->
        farewell(ctx)

      zeny(ctx) < 500_000 ->
        ctx
        |> mes("[Hianna]")
        |> mes("I'm sorry, but this")
        |> mes("isn't enough money for")
        |> mes("a Megaphone. Be sure")
        |> mes("to bring me 500,000 zeny.")
        |> close()

      true ->
        ctx
        |> mes("[Hianna]")
        |> mes("Here you are. The fact is...")
        |> mes("These Megaphones are")
        |> mes("considered guild property,")
        |> mes("so I'm not supposed to let")
        |> mes("you have this. Don't let")
        |> mes("anyone know I gave you this!")
        |> pay_zeny(500_000)
        |> give_item(7040, 1)
        |> close()
    end
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Hianna]")
    |> mes("Alright~")
    |> mes("Take care, and")
    |> mes("travel safely~")
    |> close()
  end
end
