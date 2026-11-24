defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Shaman do
  @moduledoc """
  Shaman Anori prepares purification potions to counter Iara's curse.

  ## Behavior

  - Asks adventurers for materials and prepares potions after they bring them.
  - Offers the quest again after the preparation period expires.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "brasilis",
        x: 315,
        y: 334,
        dir: 5,
        sprite: 474,
        name: "Shaman",
        scope: :shared,
        unique_name: "Shaman#nk"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx = set_local(ctx, :iara_re, checkquest(ctx, 4135, :playtime))

    if get_local(ctx, :iara_re, 0) in [0, 1] do
      ctx
      |> mes("[Anori]")
      |> mes("I'm still preparing.")
      |> mes("I don't require your help at this time.")
      |> mes("Please come back later...")
      |> close()
    else
      prepare_quest(ctx)
    end
  end

  defp prepare_quest(ctx) do
    ctx = if checkquest(ctx, 4135) > 1, do: erasequest(ctx, 4135), else: ctx
    ctx = set_local(ctx, :iara_q, checkquest(ctx, 4133))

    cond do
      get_local(ctx, :iara_q, 0) in [0, 1] ->
        materials(ctx)

      base_level(ctx) < 40 ->
        ctx
        |> mes("[Anori]")
        |> mes("Ah... we need a strong adventurer.")
        |> mes("The tribe is facing a major threat.")
        |> close()

      true ->
        offer_quest(ctx)
    end
  end

  defp materials(ctx) do
    ctx =
      ctx
      |> mes("[Anori]")
      |> mes("To block Iara ")
      |> mes("seducing the tribes")
      |> mes("we need a purifying potion...")
      |> next()
      |> mes("[Anori]")
      |> mes("Did you bring the materials")
      |> mes("to make the purifying potion?")
      |> next()

    if count_item(ctx, 950) > 19 and count_item(ctx, 7172) > 9 and count_item(ctx, 1054) > 2 do
      ctx
      |> mes("[Anori]")
      |> mes("Um... it seems to be okay.")
      |> mes("I'll make you a potion which will")
      |> mes("weaken Iara's power.")
      |> next()
      |> mes("[Anori]")
      |> mes("Let's see grind this...")
      |> mes("and mix in that...")
      |> mes("then add some magic...")
      |> next()
      |> setquest(4135)
      |> erasequest(4133)
      |> setquest(4134)
      |> completequest(4134)
      |> delitem(950, 20)
      |> delitem(7172, 10)
      |> delitem(1054, 3)
      |> give_item(11_517, 2)
      |> mes("[Anori]")
      |> mes("Here, it's completed.")
      |> mes("Take this.")
      |> mes("It will make Iara stop")
      |> mes("training at the cave")
      |> mes("for a while.")
      |> next()
      |> mes("[Anori]")
      |> mes("Please block the Iara threatening the security of the tribe.")
      |> close()
    else
      ctx
      |> mes("[Anori]")
      |> mes("You haven't brought enough materials yet.")
      |> mes("We cannot make the purification potion with only these.")
      |> close()
    end
  end

  defp offer_quest(ctx) do
    ctx = set_local(ctx, :re_q, checkquest(ctx, 4134))
    if get_local(ctx, :re_q, 0) == 2, do: repeat_quest(ctx), else: introduce_quest(ctx)
  end

  defp repeat_quest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Anori]")
      |> mes("you are...")
      |> mes("the adventurer who came for the")
      |> mes("purification potion...")
      |> next()
      |> mes("[Anori]")
      |> mes("Maybe because of the purification potion...")
      |> mes("After that, the Iara stopped seducing tribesmen but the effect didn't last long.")
      |> next()
      |> mes("[Anori]")
      |> mes("Could you get the same")
      |> mes("materials as before...")
      |> mes("I need your power.")
      |> next()
      |> select(["No.", "Okay, I'll do it."])

    case choice do
      1 ->
        ctx
        |> mes("[Anori]")
        |> mes("This, ah...")
        |> mes("There is no other way.")
        |> close()

      2 ->
        ctx
        |> mes("[Anori]")
        |> mes("You are truly brave!")
        |> mes("I, on behalf of the tribe,")
        |> mes("offer you my thanks.")
        |> next()
        |> mes("[Anori]")
        |> mes("Materials are the same as before.")
        |> mes("If you just get^ff0000 20 Hearts of Mermaids,")
        |> mes("10 Leopard Claws and")
        |> mes("3 Ancient Lips^000000,")
        |> mes("I will make you a potion that purifies evil spirits")
        |> mes("by using a secret formula handed down to the tribe.")
        |> next()
        |> mes("[Anori]")
        |> mes("The destiny of the tribe is up to you.")
        |> mes("please get the materials quickly.")
        |> mes("I will be preparing to make")
        |> mes("the purification potion right here.")
        |> setquest(4133)
        |> close()

      _ ->
        ctx
    end
  end

  defp introduce_quest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Anori]")
      |> mes("There are some people I haven't seen before around here.")
      |> mes("It's a good sign...")
      |> next()
      |> mes("[Anori]")
      |> mes("Hey you...")
      |> mes("Could you listen to my stories for a moment.")
      |> mes("There's an emergency in our tribe.")
      |> next()
      |> select(["No.", "Okay."])

    if choice == 1 do
      ctx
      |> mes("[Anori]")
      |> mes("You are a heartless person...")
      |> mes("You don't seem the helpful type.")
      |> mes("Just keep on going your way.")
      |> close()
    else
      explain_quest(ctx)
    end
  end

  defp explain_quest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Anori]")
      |> mes("Thank you, I met a kind person.")
      |> mes("It's a secret of our tribe that")
      |> mes("you cannot tell anyone.")
      |> next()
      |> mes("[Anori]")
      |> mes("Lately young men from")
      |> mes("the tribe are disappearing.")
      |> mes("Our entire tribe is being threatened.")
      |> next()
      |> mes("[Anori]")
      |> mes("It is likely because of a witch called Iara.")
      |> mes(
        "She is a water nymph seducing the hearts of young tribesmen at a cave behind the waterfall."
      )
      |> next()
      |> mes("[Anori]")
      |> mes("How can I stop these young tribesmen?")
      |> mes(
        "But I discovered a way to make a purification potion to reverse the effects of the Iara's spells."
      )
      |> next()
      |> mes("[Anori]")
      |> mes("This potion has been handed down from many generations in our tribe.")
      |> mes("This purification potion possesses the power to cleanse evil spirits.")
      |> next()
      |> mes("[Anori]")
      |> mes("If you could get the materials")
      |> mes("I will make you")
      |> mes("the purification potion.")
      |> mes("Could you do that for me?")
      |> next()
      |> select(["No.", "Yes, I can."])

    case choice do
      1 ->
        ctx
        |> mes("[Anori]")
        |> mes("Hm...")
        |> mes("Well, then.")
        |> mes("If you change your mind you can come to me again.")
        |> next()
        |> mes("[Anori]")
        |> mes("You shouldn't talk about")
        |> mes("what you heard now to anyone")
        |> mes("It's kind of embarrassing...")
        |> close()

      2 ->
        ctx
        |> mes("[Anori]")
        |> mes("Oh! You are the savior")
        |> mes("of our tribe indeed.")
        |> mes("On behalf of the tribe, I offer you my thanks.")
        |> next()
        |> mes("[Anori]")
        |> mes("Well, what we need is this.")
        |> mes("It's all you can get from near here.")
        |> mes("Note down well.")
        |> next()
        |> mes("[Anori]")
        |> mes("^ff0000 20 Hearts of Mermaids")
        |> mes("10 Leopard Claws")
        |> mes("3 Ancient Lips^000000")
        |> mes("are the only ones that are needed as the materials.")
        |> next()
        |> mes("[Anori]")
        |> mes(
          "When you get those, I will make you a potion that purifies evil spirits using a secret formula handed down to the tribe."
        )
        |> setquest(4133)
        |> next()
        |> mes("[Anori]")
        |> mes("The destiny of the tribe is up to you.")
        |> mes("I hope you move quickly.")
        |> mes("Even at this moment, the village men are being seduced and slipping way...")
        |> close()

      _ ->
        ctx
    end
  end
end
