defmodule Aesir.ZoneServer.Content.Npc.Floating.GershaunAlberta do
  @moduledoc """
  Gershaun, the cart-wielding merchant of Alberta, teaches the Cart Revolution quest skill.

  ## Behavior

  - Talks carts only with merchant-line characters and repeats his motto to everyone else.
  - Tells younger merchants the story of Cart Revolution and asks them to reach Job Level 35.
  - Offers Cart Revolution to merchant-line characters at Job Level 35 or higher, or to any
    Blacksmith or Alchemist; his material demand rolls at random among three amounts of Iron,
    Sticky Mucus, Fly Wings, and Tentacles, always with 2 Grape Juices.
  - When the materials fall short, accepts a Banana Juice in exchange for the material list.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - Silentdragon
    - IVBela
    - DracoRPG
    - L0ne_W0lf
    - Masao
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @cart_revolution 153
  @grape_juice 533
  @iron 998
  @sticky_mucus 938
  @fly_wing 601
  @tentacle 962
  @banana_juice 532

  @materials %{
    1 => [{@iron, 20}, {@sticky_mucus, 30}, {@fly_wing, 20}, {@tentacle, 5}],
    2 => [{@iron, 15}, {@sticky_mucus, 25}, {@fly_wing, 15}, {@tentacle, 5}],
    3 => [{@iron, 23}, {@sticky_mucus, 32}, {@fly_wing, 23}, {@tentacle, 6}]
  }

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_class(ctx)) != Rathena.job_id(:merchant) -> motto(ctx)
      getskilllv(ctx, @cart_revolution) == 1 -> reunion(ctx)
      experienced?(ctx) -> offer_skill(ctx)
      true -> young_merchant(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp experienced?(ctx) do
    job_level(ctx) >= 35 or
      (Rathena.job_id(base_job(ctx)) == Rathena.job_id(:blacksmith) or
         Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist))
  end

  defp reunion(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("Ah, long time no see!")
    |> mes("Ohh, the red marks on your cart.")
    |> mes("They must be the marks of 'it'...")
    |> mes("Seems like I have taught you the skill correctly!")
    |> next()
    |> mes("[Gershaun]")
    |> mes("You have blood like mine in you!")
    |> mes("Mmm! After all!!")
    |> mes("I'm happy! Scratch my back!")
    |> mes("Here! Hurry!")
    |> close()
  end

  defp offer_skill(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gershaun]")
      |> mes("Ooh. You have a firm body")
      |> mes("for a merchant. You must be")
      |> mes("very good a carrying things!?")
      |> mes("Mmm you should be able to learn")
      |> mes("Cart Revolution!")
      |> next()
      |> select(["Hey~ that's why I came.", "What's that?"])

    case choice do
      1 -> learn_attempt(ctx, Enum.random(1..3))
      2 -> tell_story(ctx)
      _ -> young_merchant(ctx)
    end
  end

  defp learn_attempt(ctx, roll) do
    materials = [{@grape_juice, 2} | Map.fetch!(@materials, roll)]

    cond do
      Enum.all?(materials, fn {item, amount} -> count_item(ctx, item) >= amount end) ->
        teach(ctx, roll, materials)

      count_item(ctx, @banana_juice) > 0 ->
        accept_banana_juice(ctx, roll)

      true ->
        ask_for_drink(ctx, roll)
    end
  end

  defp teach(ctx, roll, materials) do
    ctx
    |> mes("[Gershaun]")
    |> teach_intro(roll)
    |> next()
    |> mes("[Gershaun]")
    |> mes("Ah, such a nice day!")
    |> mes("I shall reward those who")
    |> mes("eagerly swing their carts!")
    |> next()
    |> take_materials(materials)
    |> skill(@cart_revolution, 1, :permanent)
    |> mes("Now you can use Cart Revolution")
    |> mes("I expect you to make merchants")
    |> mes(if roll == 1, do: "famous by using this amazing", else: "famous by using its amazing")
    |> mes("destruction power. Muahahahahaha!!!")
    |> next()
    |> mes("[Gershaun]")
    |> mes(if roll == 1, do: "Have a great day!!", else: "Have a good day!!")
    |> close()
  end

  defp teach_intro(ctx, 1) do
    ctx
    |> mes("Hoho!")
    |> mes("Got it! I shall teach you")
    |> mes("Cart Revolution!")
  end

  defp teach_intro(ctx, _roll) do
    ctx
    |> mes("Mmm that's good!")
    |> mes("Great! I shall teach you")
    |> mes("...Cart Revolution!")
  end

  defp take_materials(ctx, materials) do
    Enum.reduce(materials, ctx, fn {item, amount}, ctx -> delitem(ctx, item, amount) end)
  end

  defp accept_banana_juice(ctx, 1) do
    ctx
    |> mes("[Gershaun]")
    |> mes("Ooh!")
    |> mes("It's banana juice!")
    |> mes("Thank you very much!")
    |> mes("...............Kaah!")
    |> delitem(@banana_juice, 1)
    |> mes("Very refreshing! Thank you! Goodbye!")
    |> next()
    |> mes("[Gershaun]")
    |> mes("Hmm?")
    |> mes("You didn't leave yet?")
    |> mes("Ah! You are still attached")
    |> mes("to Cart Revolution!")
    |> mes("Ok then. Considering you brought")
    |> mes("the Banana Juice, I'll teach you.")
    |> next()
    |> list_materials()
    |> just_bring_those()
  end

  defp accept_banana_juice(ctx, roll) do
    ctx =
      ctx
      |> mes("[Gershaun]")
      |> mes("Ooh!")
      |> mes(if roll == 3, do: "It's Banana Juice!", else: "It's banana juice!")
      |> mes("Thanks a lot!")
      |> mes("...............Kaaah!")
      |> delitem(@banana_juice, 1)
      |> mes("Very good! Thank you! Good-bye!")
      |> next()
      |> mes("[Gershaun]")
      |> mes("Mmm?")
      |> mes("You didn't leave yet?")
      |> mes("Ah! You're still attached")
      |> mes("to Cart Revolution!")
      |> mes("Ok then. Considering you brought")
      |> mes("the banana juice, I'll teach you.")
      |> next()
      |> list_materials()

    if roll == 2, do: bring_these(ctx), else: just_bring_those(ctx)
  end

  defp list_materials(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("It's not hard to teach you")
    |> mes("Cart Revolution, but I need you to prepare")
    |> mes("the materials to modify your cart.")
    |> mes("The items I need are..")
    |> next()
    |> mes("[Gershaun]")
    |> mes("First I need 20 Irons to make the cart")
    |> mes("durable. Then 30 Sticky Mucus to absorb")
    |> mes("the shock.")
    |> mes("And about 20 Fly Wings and 5 Tentacles?")
    |> mes("And 2 bottles of Grape Juice for me!")
    |> next()
  end

  defp just_bring_those(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("Just bring those.")
    |> mes("I'm not saying ONLY 30 or 20.")
    |> mes("It depends on my condition!")
    |> mes("Hahahaha!")
    |> mes("I'll be waiting. Then byebye~")
    |> close()
  end

  defp bring_these(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("Bring these to me.")
    |> mes("But that doesn't mean I want only 30 and 20.")
    |> mes("It all depends on my condition!")
    |> mes("Just bring me these for now.")
    |> mes("Hahahaha!")
    |> mes("I'm looking forward to it. Good bye then~")
    |> close()
  end

  defp ask_for_drink(ctx, 2) do
    ctx
    |> mes("[Gershaun]")
    |> mes("Mmm!")
    |> mes("Nothing's free nowadays!")
    |> mes("How about trying to start a conversation")
    |> mes("by offering a bottle of Banana Juice or something?")
    |> close()
  end

  defp ask_for_drink(ctx, _roll) do
    ctx
    |> mes("[Gershaun]")
    |> mes("Mmm!")
    |> mes("Nothing can be done without a refreshing drink!")
    |> mes("How about starting a conversation")
    |> mes("with at least a bottle of Banana Juice?")
    |> close()
  end

  defp tell_story(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("... you don't seem to know")
    |> mes("about Cart Revolution.")
    |> mes("Ok, I'll tell you a story")
    |> mes("I've never told anyone before.")
    |> mes("Listen carefully.")
    |> next()
    |> research_page()
    |> next()
    |> despair_page()
    |> next()
    |> mes("[Gershaun]")
    |> mes("I was scared to death.. thinking")
    |> mes("and hoping that this wasn't the")
    |> mes("last of me. With little hope left")
    |> mes("I tried the last thing possible.")
    |> mes("I used my cart to hit the monster!")
    |> next()
    |> revelation_pages()
    |> mes("This is Cart Revolution!")
    |> close()
  end

  defp young_merchant(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gershaun]")
      |> mes("Mmm, a young merchant.")
      |> mes("You must use carts, too.")
      |> mes("Since you need to do business.")
      |> mes("But is that all?")
      |> next()
      |> research_page()
      |> next()
      |> select(["I know, I know.", "...?"])

    case choice do
      1 -> ctx |> mes("[Gershaun]") |> mes("...no, what I'm saying is.") |> close()
      2 -> story_for_young_merchant(ctx)
      _ -> motto(ctx)
    end
  end

  defp story_for_young_merchant(ctx) do
    {ctx, choice} =
      ctx
      |> despair_page()
      |> next()
      |> mes("[Gershaun]")
      |> mes("I was scared to death.. thinking")
      |> mes("and hoping that this wasn't the")
      |> mes("last of me. With little hope left")
      |> mes("I tried the last thing possible.")
      |> mes("I used my cart to hit the monster!")
      |> mes("And then! And then!")
      |> next()
      |> revelation_pages()
      |> next()
      |> mes("[Gershaun]")
      |> mes("Would you like to learn this skill?")
      |> next()
      |> select(["Yes!!", "I want to learn sushi skills..."])

    case choice do
      1 -> come_back_at_35(ctx)
      2 -> sushi_king(ctx)
      _ -> motto(ctx)
    end
  end

  defp come_back_at_35(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("Ok!")
    |> mes("I'll give you special training!")
    |> mes("First you need health!")
    |> mes("Get yourself to merchant")
    |> mes("level 35!")
    |> mes("We'll talk after that!")
    |> close()
  end

  defp sushi_king(ctx) do
    ctx = mes(ctx, "[Sushi King Gershaun]")

    insult =
      if sex(ctx) == get_char_var(ctx, :SEX_FEMALE, 0), do: "Stupid girl!", else: "Stupid boy!"

    ctx
    |> mes(insult)
    |> mes("It's way to early for you to")
    |> mes("even put your hands on sushi!")
    |> close()
  end

  defp research_page(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("I did research about a different")
    |> mes("way to use the cart.")
    |> mes("I tried cooking ramen")
    |> mes("and even tried jump-roping.")
    |> mes("But none of them were able")
    |> mes("to satisfy me.")
  end

  defp despair_page(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("In despair, I wandered")
    |> mes("through the fields with my cart.")
    |> mes("After wandering dazed day after day..")
    |> mes("I met a very strong monster.")
    |> mes("Life was in danger!")
    |> mes("Why me - a weaponless, armor-less merchant!")
  end

  defp revelation_pages(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("The monster died in one hit.")
    |> mes("It was then that I realized something.")
    |> mes("Carts can become weapons, too!")
    |> mes("I finally realized that we can")
    |> mes("attack with carts!")
    |> next()
    |> mes("[Gershaun]")
    |> mes("Cart Revolution!")
    |> mes("That's the new attack skill I developed.")
    |> mes("Using 12 SP you lift your cart")
    |> mes("to hit your opponent..")
    |> mes("right in the head!")
    |> next()
    |> mes("[Gershaun]")
    |> mes("The heavier your cart is, the")
    |> mes("stronger you can attack! With one hit,")
    |> mes("your opponent will be hurt and")
    |> mes("forced to back off!")
  end

  defp motto(ctx) do
    ctx
    |> mes("[Gershaun]")
    |> mes("If it doesn't work, make it work.")
    |> mes("If it doesn't work, make it work.")
    |> mes("If it doesn't work, make it work.")
    |> close()
  end
end
