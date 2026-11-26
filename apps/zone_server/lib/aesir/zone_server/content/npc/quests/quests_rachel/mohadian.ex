defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Mohadian do
  @moduledoc """
  Buys Glacial Hearts from adventurers for his bar.

  ## Behavior

  - Offers a recurring purchase after the Ice Necklace quest reaches its final stage.
  - Pays 375 zeny for each Glacial Heart delivered.

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
        x: 113,
        y: 97,
        dir: 5,
        sprite: 929,
        name: "Mohadian",
        scope: :shared,
        trigger: {10, 10}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :ice_necklace_q, 0) do
      6 -> offer_business(ctx)
      7 -> buy_hearts(ctx)
      _ -> ev_ontouch(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_business(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mohadian]")
      |> mes("I work at the bar around")
      |> mes("here, and I've heard good")
      |> mes("things about you. Some of")
      |> mes("the customers've heard that")
      |> mes("you helped Urstialla by going")
      |> mes("into that dangerous Ice Cave.")
      |> next()
      |> mes("[Mohadian]")
      |> mes("Now, are you really capable")
      |> mes("of regularly defeating the")
      |> mes("snow monsters inside there?")
      |> mes("If you are, I've got a bit of a")
      |> mes("business proposition for you.")
      |> next()
      |> emotion(:aha)
      |> mes("[Mohadian]")
      |> mes("The weather around here")
      |> mes("is naturally hot and humid,")
      |> mes("so we need ice to make cold,")
      |> mes("refreshing drinks at the pub.")
      |> mes("And the Ice Cave is the best")
      |> mes("place to get that ice, right?")
      |> next()
      |> mes("[Mohadian]")
      |> mes("If you bring me Ice Pieces")
      |> mes("from the Ice Cave, I'll buy")
      |> mes("them from you at 375 zeny")
      |> mes("each. Think of it as kind of a")
      |> mes("freelance job. I mean, if you")
      |> mes("can bring me ice, I'll buy it!.")
      |> next()
      |> mes("[Mohadian]")
      |> mes("You can make some good")
      |> mes("money, my customers can")
      |> mes("enjoy ice cold drinks, and")
      |> mes("my business will definitely")
      |> mes("benefit. We'd kill three birds")
      |> mes("with one stone! What do you say?")
      |> next()
      |> select(["No, thanks.", "Sure."])

    if choice == 1 do
      ctx
      |> mes("[Mohadian]")
      |> mes("Aww, how disappointing.")
      |> mes("I was really sure that this")
      |> mes("would be a great deal for")
      |> mes("both of us. Well, if you're")
      |> mes("willing to change your mind")
      |> mes("then we can be partners!")
      |> close()
    else
      ctx
      |> mes("[Mohadian]")
      |> mes("Great! Now, the ice that")
      |> mes("I need comes from Glacial")
      |> mes("Hearts. You can obtain those")
      |> mes("by hunting the snow monsters")
      |> mes("in the Ice Cave. Remember, I'll")
      |> mes("pay you 375 zeny for each one!")
      |> set_char_var(:ice_necklace_q, 7)
      |> close()
    end
  end

  defp buy_hearts(ctx) do
    if count_item(ctx, 7561) < 1 do
      ctx
      |> mes("[Mohadian]")
      |> mes("Bring me some Glacial")
      |> mes("Hearts from the Ice Cave,")
      |> mes("and I'll be sure to compensate")
      |> mes("you with some zeny. This is a")
      |> mes("really good deal for the two")
      |> mes("of us when you think about it.")
      |> close()
    else
      ctx =
        ctx
        |> mes("[Mohadian]")
        |> mes("Perfect, you brought me")
        |> mes("some Glacial Hearts! I can")
        |> mes("never get used to the beauty")
        |> mes("and purity of these ice crystals.")
        |> next()
        |> mes("[Mohadian]")
        |> mes("Yes, I think I might")
        |> mes("even be able to use these")
        |> mes("to make Arunafeltz Glacial")
        |> mes("Wine. Anyway, let me see")
        |> mes("how many you've brought me.")
        |> next()

      hearts = count_item(ctx, 7561)
      total_price = 375 * hearts

      ctx
      |> mes("[Mohadian]")
      |> mes(Rathena.concat(hearts, " Glacial Hearts"))
      |> mes("at 375 zeny each...")
      |> mes("Looks like I owe you")
      |> mes(Rathena.concat(total_price, " zeny. Here you are!"))
      |> mes("It's always a pleasure")
      |> mes("doing business with you~")
      |> delitem(7561, hearts)
      |> credit_zeny(total_price)
      |> close()
    end
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :ice_necklace_q, 0) == 6 do
      ctx
      |> mes("[Mohadian]")
      |> mes("Welcome to--")
      |> mes("Er? Hello?")
      |> mes("Excuse me?")
      |> close()
    else
      ctx
    end
  end
end
