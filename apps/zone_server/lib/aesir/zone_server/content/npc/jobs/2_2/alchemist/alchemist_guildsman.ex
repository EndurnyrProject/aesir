defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Alchemist.AlchemistGuildsman do
  @moduledoc """
  Parmy Gianino registers Merchants with the Alchemist Union for the Alchemist job quest.

  ## Behavior

  - Turns away baby classes, Alchemists, Novices, and other non-Merchants with flavor dialogue.
  - Explains the Alchemist Union to Merchants who ask about it.
  - Registers Merchants of Job Level 40 or more for a 50,000 Zeny fee and assigns one of
    three random item requirements.
  - Accepts the assigned items, or an Old Magic Book with a Hammer of Blacksmith instead,
    and sends the candidate on to Raspuchin.

  ## Credits

  - Original from rAthena, authors and Contributors
    - nestor_zulueta
    - Darkchild
    - L0ne_W0lf
    - Kisuka
    - kobra_k88
    - Lupus
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alde_alche",
        x: 27,
        y: 185,
        dir: 5,
        sprite: 744,
        name: "Alchemist Guildsman",
        scope: :shared,
        unique_name: "Alchemist Guildsman#am"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FInsertplural
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @old_magic_book 1006
  @hammer_of_blacksmith 1005

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Parmy Gianino]")

    cond do
      upper(ctx) == 1 -> greet_baby(ctx)
      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:merchant) -> greet_non_merchant(ctx)
      true -> talk_to_merchant(ctx, get_char_var(ctx, :ALCH_Q, 0))
    end
  end

  defp greet_baby(ctx) do
    ctx
    |> mes("Welcome to the")
    |> mes("Alchemist Unio--")
    |> mes("I-Impossible! How c-can")
    |> mes("something like this happen?")
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes("Wait, wait...")
    |> mes("I'm sorry. I was confused,")
    |> mes("that's all. You look just like")
    |> mes("someone I used to know. ")
    |> mes("Still, I get this weird")
    |> mes("feeling about you...")
    |> close()
  end

  defp greet_non_merchant(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist) -> greet_alchemist(ctx)
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) -> greet_novice(ctx)
      true -> greet_other_job(ctx)
    end
  end

  defp greet_alchemist(ctx) do
    ctx
    |> mes("Welcome, #{char_name(ctx, 0)}.")
    |> mes("The Alchemist Union")
    |> mes("is busy today, like always.")
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes("Everyone is busy with their")
    |> mes(
      "own research, but recently, some headway has been made in the field of biotechnology."
    )
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes(
      "Everyone is hoping that the biotechnological studies will yield positive results. Speaking of which, I wonder how the Alchemists working on artificial life are doing..."
    )
    |> close()
  end

  defp greet_novice(ctx) do
    ctx
    |> recruiting_greeting()
    |> mes(
      "If you're interested in working with chemistry, visit us later when you become more knowledgable."
    )
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes("Just one thing:")
    |> mes("You've got to have")
    |> mes("knowledge of items")
    |> mes("as a Merchant first.")
    |> close()
  end

  defp greet_other_job(ctx) do
    ctx
    |> recruiting_greeting()
    |> mes(
      "If you know any exceptional Merchants, by all means, please refer them to us. Those types of people tend to have a talent for Alchemy and experimentation~"
    )
    |> close()
  end

  defp recruiting_greeting(ctx) do
    ctx
    |> mes("Welcome to the")
    |> mes("Alchemist Union.")
    |> mes("We are recruiting")
    |> mes("talented people")
    |> mes("with novel ideas.")
    |> next()
    |> mes("[Parmy Gianino]")
  end

  defp talk_to_merchant(ctx, 0) do
    {ctx, choice} =
      ctx
      |> mes("Welcome to the")
      |> mes("Alchemist Union.")
      |> mes("How may I help you?")
      |> next()
      |> select([
        "I would like to learn about Alchemists.",
        "I want to become an Alchemist.",
        "Nothing."
      ])

    case choice do
      1 -> explain_alchemists(ctx)
      2 -> offer_registration(ctx)
      3 -> decline_help(ctx)
      _ -> ctx
    end
  end

  defp talk_to_merchant(ctx, step) when step >= 1 and step <= 3 do
    if count_item(ctx, @old_magic_book) > 0 and count_item(ctx, @hammer_of_blacksmith) > 0 do
      ctx
      |> mes("Well now~!")
      |> mes("You've brought an")
      |> mes("Old Magic Book and")
      |> mes("a Hammer of Blacksmith.")
      |> mes("We'll put these items")
      |> mes("to good use.")
      |> next()
      |> delitem(@old_magic_book, 1)
      |> delitem(@hammer_of_blacksmith, 1)
      |> begin_training()
    else
      turn_in_required_items(ctx, required_items(step))
    end
  end

  defp talk_to_merchant(ctx, 4) do
    ctx
    |> mes("Go and talk to")
    |> mes("Mr. Raspuchin.")
    |> mes("He's involved in the")
    |> mes("Alchemist selection process, whatever that might mean.")
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes("Hopefully, it")
    |> mes("won't be too much of")
    |> mes("a problem. I guess he'll just interview you, and ask you")
    |> mes("some simple questions.")
    |> close()
  end

  defp talk_to_merchant(ctx, _step) do
    ctx
    |> mes("Ah, I'm sorry, but")
    |> mes("I'm busy right now~")
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes("Why don't you ask")
    |> mes("someone else if you're")
    |> mes("not sure who to visit")
    |> mes("next? Good luck~")
    |> close()
  end

  defp decline_help(ctx) do
    ctx
    |> mes("[Parmy Gianino]")
    |> mes("Umm...")
    |> mes("Please let me know")
    |> mes("if you need anything.")
    |> close()
  end

  defp explain_alchemists(ctx) do
    ctx
    |> mes("[Parmy Gianino]")
    |> mes(
      "Alchemists study and create new substances and items out of existing materials. Our knowledge allows us to change the properties of chemicals at the atomic level."
    )
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes("Most people think our final goal")
    |> mes(
      "is to create gold, but that's not the entire truth. We also want to create things like medicines"
    )
    |> mes("and new materials.")
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes("A few of us research the")
    |> mes(
      "creation of life, although many of us consider that god's territory. That field is so complex, most of us deal with slightly less complicated projects anyway."
    )
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes(
      "If you are interested in becoming an Alchemist, I recommend that you first get a lot of experience as a Merchant. Being a Merchant is a great opportunity to learn about materials as you deal with them."
    )
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes("Whether or not you try to become")
    |> mes(
      "an Alchemist is your decision. The road to becoming an Alchemist is very challenging, and you'll need to focus on experimentation and research, instead of commerce."
    )
    |> close()
  end

  defp offer_registration(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Parmy Gianino]")
      |> mes("Is that so?")
      |> mes("Nice to meet you.")
      |> mes("My name is Parmy Gianino")
      |> mes("of the Alchemist Union.")
      |> next()
      |> mes("[Parmy Gianino]")
      |> mes("If you join our Union and")
      |> mes("complete the training, you")
      |> mes("will be officially recognized")
      |> mes("as an Alchemist and be able")
      |> mes("to contribute to our research.")
      |> next()
      |> mes("[Parmy Gianino]")
      |> mes("But we don't accept everyone.")
      |> mes("You must have a lot of tenacity")
      |> mes("and sincere devotion in exploring")
      |> mes("the various fields of science.")
      |> next()
      |> mes("[Parmy Gianino]")
      |> mes("There are a couple")
      |> mes("of requirements to join")
      |> mes("the Alchemist Union, but")
      |> mes("we'll discuss that")
      |> mes("after you apply.")
      |> next()
      |> mes("[Parmy Gianino]")
      |> mes("Well then, would")
      |> mes("you like to apply")
      |> mes("for registration?")
      |> next()
      |> select(["I would like to apply.", "I'll do it later."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Parmy Gianino]")
        |> mes("Talented Merchants")
        |> mes("are always welcome here.")
        |> mes("Please come back soon.")
        |> close()

      job_level(ctx) < 40 ->
        ctx
        |> mes("[Parmy Gianino]")
        |> mes("Hmmm...")
        |> mes("Just a moment.")
        |> mes("I'm sorry to say that")
        |> mes("you're not experienced")
        |> mes("enough as a Merchant to")
        |> mes("join us right now.")
        |> next()
        |> mes("[Parmy Gianino]")
        |> mes("You must be at least")
        |> mes("^551A8BJob Level 40^000000 to become")
        |> mes("an Alchemist. Come back")
        |> mes("later when you meet the")
        |> mes("Job Level requirement, okay?")
        |> close()

      true ->
        register(ctx)
    end
  end

  defp register(ctx) do
    ctx =
      ctx
      |> mes("[Parmy Gianino]")
      |> mes(
        "Alright, your application has been accepted. Now, you must pay the 50,000 Zeny application fee and bring some items before you can begin your formal training."
      )
      |> next()
      |> mes("[Parmy Gianino]")
      |> mes(
        "But if you bring an ^551A8BOld Magic Book^000000 and ^551A8BHammer of Blacksmith^000000,"
      )
      |> mes("we will accept that as a substitute for the item requirement.")
      |> next()
      |> mes("[Parmy Gianino]")
      |> mes("Now...")
      |> mes("Please sign")
      |> mes("the application.")
      |> next()

    {ctx, _signature} = select(ctx, String.split(to_string(char_name(ctx, 0)), ":"))

    ctx =
      ctx
      |> mes("[Parmy Gianino]")
      |> mes("Good, good. Now, if you have")
      |> mes(
        "the Zeny for your application fee ready, I will tell you which items you will need to bring. Now, pay attention."
      )
      |> next()

    if zeny(ctx) < 50_000 do
      ctx
      |> mes("[Parmy Gianino]")
      |> mes("Uh oh. You don't")
      |> mes("seem to have enough Zeny.")
      |> mes(
        "Come back to me when you have 50,000 Zeny, otherwise we can't process your application."
      )
      |> close()
    else
      ctx
      |> pay_zeny(50_000)
      |> mes("[Parmy Gianino]")
      |> mes("Let's see.")
      |> mes(char_name(ctx, 0))
      |> mes("needs to bring...")
      |> assign_required_items(Enum.random(1..3))
      |> next()
      |> mes("[Parmy Gianino]")
      |> mes("Once you've gathered")
      |> mes("those items, come back")
      |> mes("to me and your training")
      |> mes("as an Alchemist will begin.")
      |> mes("See you soon~")
      |> close()
    end
  end

  defp assign_required_items(ctx, 1) do
    ctx
    |> set_char_var(:ALCH_Q, 1)
    |> setquest(2028)
    |> mes("^551A8B7 Berserk Potions^000000.")
  end

  defp assign_required_items(ctx, 2) do
    ctx
    |> set_char_var(:ALCH_Q, 2)
    |> setquest(2029)
    |> mes("^551A8B100 Mini Furnaces^000000.")
  end

  defp assign_required_items(ctx, 3) do
    ctx
    |> set_char_var(:ALCH_Q, 3)
    |> setquest(2030)
    |> mes("^551A8B7,500 Fire Arrows^000000.")
  end

  defp required_items(1), do: {657, 7}
  defp required_items(2), do: {612, 100}
  defp required_items(3), do: {1752, 7500}
  defp required_items(_step), do: {0, 0}

  defp turn_in_required_items(ctx, {item_id, amount}) do
    if count_item(ctx, item_id) >= amount do
      ctx =
        ctx
        |> mes("Seems like")
        |> mes("you're all ready.")
        |> mes("The Union will put")
        |> mes("these items to good use.")
        |> next()

      ctx
      |> delitem(item_id, amount)
      |> begin_training()
    else
      ctx =
        ctx
        |> mes("Aren't you ready?")
        |> mes("Like I said before,")
        |> mes("you must bring")

      {ctx, items_text} = FInsertplural.call(ctx, [amount, Rathena.getitemname(item_id)])

      ctx
      |> mes("^551A8B#{items_text}^000000.")
      |> next()
      |> mes("[Parmy Gianino]")
      |> mes("Come back when you")
      |> mes("have prepared the")
      |> mes("required items.")
      |> close()
    end
  end

  defp begin_training(ctx) do
    ctx =
      ctx
      |> mes("[Parmy Gianino]")
      |> mes("Okay, now you need to learn")
      |> mes(
        "the basics to being an Alchemist and learn the procedures for mixing chemicals and medicines."
      )
      |> set_char_var(:ALCH_Q, 4)

    ctx =
      cond do
        checkquest(ctx, 2028) != -1 -> changequest(ctx, 2028, 2031)
        checkquest(ctx, 2029) != -1 -> changequest(ctx, 2029, 2031)
        true -> changequest(ctx, 2030, 2031)
      end

    ctx
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes(
      "But before all of that, you need to speak to Raspuchin. I'm not really sure what you'll be talking about with him..."
    )
    |> next()
    |> mes("[Parmy Gianino]")
    |> mes(
      "It shouldn't be anything extraordinary, but you're still required to speak to Raspuchin, since apparently he's a part of the Alchemist selection process."
    )
    |> close()
  end
end
