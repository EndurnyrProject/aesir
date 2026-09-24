defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.SirEdmond do
  @moduledoc """
  Contemplative Knight who runs the fifth Knight job test, a trial of patience.

  ## Behavior

  - Sends candidates who passed Lady Amy's test to the patience test arena and
    advances the quest log.
  - Lets candidates who failed by attacking the arena monsters retake the test.
  - Offers philosophical advice to everyone else.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 70,
        y: 99,
        dir: 6,
        sprite: 734,
        name: "Sir Edmond",
        scope: :shared,
        unique_name: "Sir Edmond#knt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Sir Edmond]")

    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:swordman) do
      greet_non_swordman(ctx)
    else
      talk_about_test(ctx, get_char_var(ctx, :KNIGHT_Q, 0))
    end
  end

  defp greet_non_swordman(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) -> greet_knight(ctx)
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) -> greet_novice(ctx)
      true -> greet_visitor(ctx)
    end
  end

  defp greet_knight(ctx) do
    ctx
    |> mes("Think of your")
    |> mes("mind as if it were")
    |> mes("flowing water.")
    |> next()
    |> mes("[Sir Edmond]")
    |> mes("Flowing water")
    |> mes("avoids obstacles,")
    |> mes("going on its way...")
    |> next()
    |> mes("[Sir Edmond]")
    |> mes("Knights must be")
    |> mes("able to pass things,")
    |> mes("like calm water, in")
    |> mes("any situation.")
    |> close()
  end

  defp greet_novice(ctx) do
    ctx
    |> mes(
      "Trees with deep roots don't sway with the wind. The fact that powerful skills must be built on strong basics is immutable..."
    )
    |> next()
    |> mes("[Sir Edmond]")
    |> mes("Your future")
    |> mes("can even be")
    |> mes("decided now...")
    |> close()
  end

  defp greet_visitor(ctx) do
    ctx
    |> mes(
      "Everything in this world exists in harmony. Living without disrupting this harmony is the right way to live..."
    )
    |> close()
  end

  defp talk_about_test(ctx, quest) do
    cond do
      quest == 0 -> share_dream_wisdom(ctx)
      quest >= 1 and quest <= 9 -> redirect_early_candidate(ctx)
      quest == 10 -> offer_patience_test(ctx)
      quest == 11 -> offer_patience_retest(ctx)
      quest == 12 or quest == 13 -> send_to_sir_gray(ctx)
      true -> send_to_captain(ctx)
    end
  end

  defp share_dream_wisdom(ctx) do
    ctx
    |> mes(
      "Those with ominous thoughts will only dream such dreams. It's better to have no dreams at all than to have dreams of sadness and despair."
    )
    |> close()
  end

  defp redirect_early_candidate(ctx) do
    {ctx, choice} =
      ctx
      |> mes("What is it...")
      |> mes("Wandering Swordman?")
      |> next()
      |> select(["I would like to take the test to change jobs.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Edmond]")
      |> mes("A seed must first be nestled")
      |> mes(
        "in the earth before the seed may sprout. Then, the sprout must grow leaves before its buds blossom into flowers..."
      )
      |> next()
      |> mes("[Sir Edmond]")
      |> mes("If not...")
      |> mes("The flower will")
      |> mes("be incomplete.")
      |> next()
      |> mes("[Sir Edmond]")
      |> mes("Go to the others")
      |> mes("first, so that you")
      |> mes("may find your path...")
      |> close()
    else
      promise_perfect_order(ctx)
    end
  end

  defp offer_patience_test(ctx) do
    {ctx, choice} =
      ctx
      |> mes("What is it...")
      |> mes("Wandering Swordman.")
      |> next()
      |> select(["Lady Amy sent me.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Edmond]")
      |> mes(
        "It is now time to take my test. Please do your best, as you have done on the other tests."
      )
      |> next()
      |> mes("[Sir Edmond]")
      |> mes("My name is")
      |> mes("Edmond Groster.")
      |> mes("I am a member of")
      |> mes("the Prontera Chivalry.")
      |> next()
      |> mes("[Sir Edmond]")
      |> mes(
        "Knights are in the position for others to follow. Therefore, you must modestly think about the world's order and have the personality to fit the role you will play."
      )
      |> next()
      |> mes("[Sir Edmond]")
      |> mes(
        "You must not make careless decisions. Your will should bend as the reeds or be as firm as stone when the situation calls for it."
      )
      |> next()
      |> mes("[Sir Edmond]")
      |> mes(
        "You must not kill monsters without reason and not take joy in doing so. Take this time to quietly think about this on your own..."
      )
      |> next()
      |> mes("[Sir Edmond]")
      |> mes("Then, we shall")
      |> mes("begin the test.")
      |> mes("Keep in mind")
      |> mes("the quality of")
      |> mes("reverence.")
      |> close()
      |> set_char_var(:KNIGHT_Q, 11)
      |> changequest(9009, 9010)
      |> warp("job_knt", 143, 57)
    else
      ctx
      |> mes("[Sir Edmond]")
      |> mes("The life you want")
      |> mes("will soon be before")
      |> mes("your eyes.")
      |> close()
    end
  end

  defp offer_patience_retest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("What is it...")
      |> mes("Wandering Swordman?")
      |> next()
      |> select(["I'm sorry, I didn't mean to...", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Edmond]")
      |> mes(
        "You were too careless in the last test. A Knight's sword exists to protect others, not to torment weaker monsters."
      )
      |> next()
      |> mes("[Sir Edmond]")
      |> mes(
        "In a world where everything exists in harmony, you can't have humans continuously destroying without purpose. This principle applies to the real world, not to this test alone."
      )
      |> next()
      |> mes("[Sir Edmond]")
      |> mes("The test")
      |> mes("shall begin.")
      |> mes("Show me your")
      |> mes("patience...")
      |> close()
      |> warp("job_knt", 143, 57)
    else
      promise_perfect_order(ctx)
    end
  end

  defp send_to_sir_gray(ctx) do
    ctx
    |> mes(
      "I have seen your character for myself. It is now time for you to take the last test. Go and speak"
    )
    |> mes("to Sir Gray...")
    |> close()
  end

  defp send_to_captain(ctx) do
    ctx
    |> mes("Go and speak")
    |> mes("to our captain.")
    |> mes("The time has come")
    |> mes("for all of us to")
    |> mes("evaluate your")
    |> mes("performance.")
    |> close()
  end

  defp promise_perfect_order(ctx) do
    ctx
    |> mes("[Sir Edmond]")
    |> mes("The life that you")
    |> mes("want will soon be")
    |> mes("before your eyes.")
    |> mes("Everything will")
    |> mes("come in perfect")
    |> mes("order.")
    |> close()
  end
end
