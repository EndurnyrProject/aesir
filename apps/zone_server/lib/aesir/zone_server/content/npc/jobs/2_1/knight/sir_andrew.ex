defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.SirAndrew do
  @moduledoc """
  Knight who runs the first Knight job test, a trial of loyalty through item gathering.

  ## Behavior

  - Waives the test for Job Level 50 Swordmen and sends them on to Sir Siracuse.
  - Otherwise asks for one of two random sets of six monster drops, five of each.
  - Takes the full set when it is brought back and advances the quest to Sir
    Siracuse's test; lists the set again when anything is missing.

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
        x: 75,
        y: 107,
        dir: 4,
        sprite: 65,
        name: "Sir Andrew",
        scope: :shared,
        unique_name: "Sir Andrew#knt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @loyalty_items %{
    2 => [{1040, 5}, {7006, 5}, {931, 5}, {1057, 5}, {903, 5}, {1028, 5}],
    3 => [{1042, 5}, {950, 5}, {1032, 5}, {966, 5}, {7031, 5}, {946, 5}]
  }

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Sir Andrew]")

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
      true -> describe_chivalry(ctx)
    end
  end

  defp greet_knight(ctx) do
    ctx
    |> mes("You must be")
    |> mes("a member of")
    |> mes("the Chivalry.")
    |> mes("How are you doing?")
    |> next()
    |> mes("[Sir Andrew]")
    |> mes(
      "You must work diligently to gather food as well as save zeny to buy equipment. Save everything you"
    )
    |> mes("find in battle, even the smallest Jellopy.")
    |> next()
    |> mes("[Sir Andrew]")
    |> mes("But it's not good")
    |> mes("to be too greedy.")
    |> mes("After all, we are Knights.")
    |> close()
  end

  defp greet_novice(ctx) do
    ctx
    |> mes("Hey there,")
    |> mes("little Novice.")
    |> mes("Welcome to the")
    |> mes("Prontera Chivalry.")
    |> next()
    |> mes("[Sir Andrew]")
    |> mes("You might that you're")
    |> mes("weak right now, but someday")
    |> mes("you'll become stronger.")
    |> next()
    |> mes("[Sir Andrew]")
    |> mes("Dream of a bright future, and go look forward on the path that you choose to take.")
    |> close()
  end

  defp describe_chivalry(ctx) do
    ctx
    |> mes("We, the members of the")
    |> mes("Prontera Chivalry, are putting our best effort in protecting peace in this world.")
    |> next()
    |> mes("[Sir Andrew]")
    |> mes("Even during the battles we face each and every day, we dream of")
    |> mes("a bright future that is to come.")
    |> close()
  end

  defp talk_about_test(ctx, quest) do
    cond do
      quest == 0 -> describe_chivalry(ctx)
      quest == 1 -> offer_loyalty_test(ctx)
      quest == 2 or quest == 3 -> check_loyalty_items(ctx, quest)
      quest == 4 -> hurry_to_sir_siracuse(ctx)
      quest == 14 -> send_to_captain(ctx)
      true -> encourage(ctx)
    end
  end

  defp offer_loyalty_test(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Good day.")
      |> mes("May I help you")
      |> mes("with something?")
      |> next()
      |> select(["I would like to take the test.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Andrew]")
      |> mes("Ah...")
      |> mes("You wish")
      |> mes("to become a Knight.")
      |> mes("Your name is")
      |> mes("#{char_name(ctx, 0)},")
      |> mes("correct?")
      |> next()
      |> mes("[Sir Andrew]")
      |> mes("I am a Knight of")
      |> mes("the Prontera Chivalry,")
      |> mes("Andrew Shylock.")
      |> mes("I am in charge of")
      |> mes("your first test.")
      |> next()
      |> mes("[Sir Andrew]")
      |> mes(
        "I will be testing your sense of loyalty. Every Knight must possess this virtue. For this exam, you will be gathering prizes from"
      )
      |> mes("the battlefield.")
      |> next()
      |> start_loyalty_test()
    else
      ctx |> mes("[Sir Andrew]") |> mes("Well, then...") |> mes("Good day.") |> close()
    end
  end

  defp start_loyalty_test(ctx) do
    if job_level(ctx) == 50 do
      waive_loyalty_test(ctx)
    else
      assign_loyalty_items(ctx)
    end
  end

  defp waive_loyalty_test(ctx) do
    ctx
    |> mes("[Sir Andrew]")
    |> mes("Mmm...?")
    |> mes("Hold on there.")
    |> mes("You look like you've")
    |> mes("mastered being")
    |> mes("a Swordsman.")
    |> next()
    |> mes("[Sir Andrew]")
    |> mes("Impressive...!")
    |> mes("On second thought,")
    |> mes("I don't think your")
    |> mes("loyalty needs to")
    |> mes("be tested.")
    |> next()
    |> mes("[Sir Andrew]")
    |> mes(
      "Please go to my fellow Knight, Sir Siracuse, as he will give you your next test. Well done in mastering the Swordman job."
    )
    |> set_char_var(:KNIGHT_Q, 4)
    |> changequest(9000, 9003)
    |> close()
  end

  defp assign_loyalty_items(ctx) do
    ctx =
      ctx
      |> mes("[Sir Andrew]")
      |> mes("Without")
      |> mes("further ado,")
      |> mes("let's begin!")
      |> mes("Go and gather the")
      |> mes("following items...")
      |> next()
      |> mes("[Sir Andrew]")

    quest =
      case Enum.random(1..2) do
        1 -> 2
        2 -> 3
      end

    ctx = set_char_var(ctx, :KNIGHT_Q, quest)

    ctx =
      if get_char_var(ctx, :KNIGHT_Q, 0) == 2 do
        changequest(ctx, 9000, 9001)
      else
        changequest(ctx, 9000, 9002)
      end

    ctx
    |> mes_item_list(Map.fetch!(@loyalty_items, quest))
    |> next()
    |> mes("[Sir Andrew]")
    |> mes("I shall be")
    |> mes("waiting here for")
    |> mes("you to bring the")
    |> mes("items I've listed.")
    |> mes("See you soon~")
    |> close()
  end

  defp check_loyalty_items(ctx, quest) do
    items = Map.fetch!(@loyalty_items, quest)

    ctx =
      ctx
      |> mes("Welcome back~")
      |> mes("Did you gather")
      |> mes("all the items?")
      |> mes("Let's check and see...")
      |> next()

    if Enum.all?(items, fn {item_id, amount} -> count_item(ctx, item_id) >= amount end) do
      accept_loyalty_items(ctx, items)
    else
      ctx
      |> mes("[Sir Andrew]")
      |> mes("Wait, wait...")
      |> mes("I think you're")
      |> mes("still missing some")
      |> mes("items. In case you")
      |> mes("forgot, let me")
      |> mes("remind you...")
      |> next()
      |> mes("[Sir Andrew]")
      |> mes_item_list(items)
      |> next()
      |> mes("[Sir Andrew]")
      |> mes("Now, please take this test seriously and with sincerity.")
      |> mes("Now, I'll be waiting for you")
      |> mes("to complete this task.")
      |> close()
    end
  end

  defp accept_loyalty_items(ctx, items) do
    ctx =
      ctx
      |> mes("[Sir Andrew]")
      |> mes(
        "Perfect! We appreciate your effort in gathering these items. Thesee will be used to support the Chivalry's finances."
      )
      |> next()

    ctx = Enum.reduce(items, ctx, fn {item_id, amount}, ctx -> delitem(ctx, item_id, amount) end)

    ctx =
      if get_char_var(ctx, :KNIGHT_Q, 0) == 2 do
        changequest(ctx, 9001, 9003)
      else
        changequest(ctx, 9002, 9003)
      end

    ctx
    |> set_char_var(:KNIGHT_Q, 4)
    |> mes("[Sir Andrew]")
    |> mes(
      "Please visit my fellow Knight, Sir Siracuse, and continue the tests with the dedication and loyalty you've shown to me this day."
    )
    |> close()
  end

  defp mes_item_list(ctx, [first, second, third, fourth, fifth, sixth]) do
    ctx
    |> mes(item_line(first, ","))
    |> mes(item_line(second, ","))
    |> mes(item_line(third, ","))
    |> mes(item_line(fourth, ","))
    |> mes(item_line(fifth, " and"))
    |> mes(item_line(sixth, ","))
  end

  defp item_line({item_id, amount}, separator) do
    "^236B8E#{amount} #{Rathena.getitemname(item_id)}^000000#{separator}"
  end

  defp hurry_to_sir_siracuse(ctx) do
    ctx
    |> mes(
      "Did you have something you needed to ask me? You should go and take the next test. Hurry, Sir Siracuse is waiting for you~"
    )
    |> close()
  end

  defp send_to_captain(ctx) do
    ctx
    |> mes(
      "You must have finished all the tests. Good job! You should go see our Captain so that we can all give our evaluation."
    )
    |> close()
  end

  defp encourage(ctx) do
    ctx
    |> mes(
      "Did you have something you needed to ask me? You should go and take your next test. Do your best."
    )
    |> mes("I know you can do it!")
    |> close()
  end
end
