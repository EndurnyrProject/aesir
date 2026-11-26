defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.IdleMerchant do
  @moduledoc """
  A merchant with an unusual line of merchandise.

  ## Behavior

  - Offers information during the search for Phobe.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 138,
        y: 73,
        dir: 5,
        sprite: 85,
        name: "Idle Merchant",
        scope: :shared,
        unique_name: "Idle Merchant#ra_in01"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :lost_boy, 0) < 4 or get_char_var(ctx, :lost_boy, 0) >= 6 -> idle(ctx)
      get_char_var(ctx, :lost_boy, 0) == 4 -> ask_about_phobe(ctx)
      get_char_var(ctx, :lost_boy, 0) >= 5 -> reminder(ctx)
      true -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp idle(ctx) do
    ctx
    |> mes("[Idle Merchant]")
    |> mes("Man! Business is going")
    |> mes("sooo slooow right now!")
    |> mes("Well, no point standing")
    |> mes("around this dump much")
    |> mes("longer. Maybe I should")
    |> mes("pack it up and go home.")
    |> close()
  end

  defp ask_about_phobe(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Excuse me?")
      |> mes("Hello? Sir?")
      |> next()
      |> mes("[Idle Merchant]")
      |> mes("Finally! A customer!")
      |> mes("I knew someone would come")
      |> mes("eventually! So whaddya want")
      |> mes("to buy? I got all sorts of")
      |> mes("handy little knickknacks~")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Sorry, not interested.")
      |> mes("I just wanted to ask if")
      |> mes("you've seen a boy around")
      |> mes("here that's about fifteen")
      |> mes("years old. He supposedly")
      |> mes("ran away from home, so.")
      |> next()
      |> mes("[Idle Merchant]")
      |> mes("Fifteen? My own son is")
      |> mes("that age... I'm sorry, but")
      |> mes("I haven't seen any lads that")
      |> mes("age around here in the past")
      |> mes("few days. Though, you might")
      |> mes("want to ask the other merchants.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Cool. Thanks a lot.")
      |> next()
      |> mes("[Idle Merchant]")
      |> mes("Alright, then!")
      |> mes("Good luck bringing that")
      |> mes("boy home! Oh, and are you")
      |> mes("sure that you don't want")
      |> mes("to take a look around?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Er, what exactly do")
      |> mes("you sell here? I can't")
      |> mes("recognize any of these")
      |> mes("goods that you're selling.")
      |> next()
      |> mes("[Idle Merchant]")
      |> mes("You know how some restaurants")
      |> mes("offer dishes with mock meat")
      |> mes("made out of vegetables and")
      |> mes("stuff like wheat gluten, right?")
      |> next()
      |> mes("[Idle Merchant]")
      |> mes("Get this: mock vegetables")
      |> mes("made out of pure meat! Now")
      |> mes("how's that for the best of both")
      |> mes("worlds? Yeah? Yeah? Here,")
      |> mes("why don't you try a sample?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What the?!")
      |> mes("No way in hell am")
      |> mes("I putting that in my")
      |> mes("mouth! What the heck")
      |> mes("is that supposed to be?")
      |> next()
      |> mes("[Idle Merchant]")
      |> mes("It's the world's")
      |> mes("first zucchini...")
      |> mes("Made completely out")
      |> mes("of Grade A Sirloin Steak!")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("No no no! I've got to")
    |> mes("go and ask those other")
    |> mes("merchants about that")
    |> mes("missing boy. Er, but")
    |> mes("good luck selling that.")
    |> set_char_var(:lost_boy, 5)
    |> close()
  end

  defp reminder(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("(^333333I better ask the other")
    |> mes("merchants around here if")
    |> mes("they've seen that boy. I'm")
    |> mes("wasting my time talking to")
    |> mes("this crazy merchant and his")
    |> mes("ridiculous mock vegetables.^000000)")
    |> close()
  end
end
