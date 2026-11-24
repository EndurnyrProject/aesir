defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Layoma do
  @moduledoc """
  Layoma is a customer in Cellette's Fish Cake Soup delivery quest.

  ## Behavior

  - Requests a Mushroom Spore before accepting the soup.
  - Accepts both items and advances the delivery quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hugel", x: 84, y: 125, dir: 3, sprite: 700, name: "Layoma", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    delivery = get_char_var(ctx, :hg_odeng, 0)

    cond do
      delivery == 3 and Rathena.truthy?(count_item(ctx, 584)) ->
        request_item(ctx)

      delivery == 8 and Rathena.truthy?(count_item(ctx, 584)) and
          Rathena.truthy?(count_item(ctx, 921)) ->
        accept_delivery(ctx)

      delivery == 8 ->
        remind_player(ctx)

      true ->
        greet(ctx)
    end
  end

  defp request_item(ctx) do
    ctx
    |> mes("[Layoma]")
    |> mes("You're here to deliver")
    |> mes("my Fish Cake Soup?")
    |> mes("How could you be so late?!")
    |> mes("Don't you know that your")
    |> mes("incompetence also reflects")
    |> mes("on Cellette and her shop?!")
    |> next()
    |> mes("[Layoma]")
    |> mes("I can't let you continue")
    |> mes("delivering for Cellette")
    |> mes("unless you prove that you're")
    |> mes("dependable to me. Erm, bring")
    |> mes("me ^FF00001 Mushroom Spore^000000, and")
    |> mes("I'll forget this whole thing.")
    |> set_char_var(:hg_odeng, 8)
    |> changequest(8066, 8070)
    |> close()
  end

  defp greet(ctx) do
    ctx
    |> mes("[Layoma]")
    |> mes("I love singing songs,")
    |> mes("and I love eating mushrooms.")
    |> mes("For a person living in Hugel,")
    |> mes("that's a pretty exciting life!")
    |> close()
  end

  defp accept_delivery(ctx) do
    ctx
    |> mes("[Layoma]")
    |> mes("Great! You brought me")
    |> mes("1 Mushroom Spore! This")
    |> mes("will taste perfect with my")
    |> mes("bowl of Fish Cake Soup~")
    |> next()
    |> mes("[Layoma]")
    |> mes("Alright, maybe I can")
    |> mes("count on you to work")
    |> mes("for my roommate Cellette")
    |> mes("a little while longer. Oh, and")
    |> mes("please tell her to not to come home so late all the time, okay?")
    |> delitem(921, 1)
    |> delitem(584, 1)
    |> set_char_var(:hg_odeng, 10)
    |> changequest(8070, 8074)
    |> close()
  end

  defp remind_player(ctx) do
    ctx
    |> mes("[Layoma]")
    |> mes("Hey! I thought you")
    |> mes("wanted to prove that")
    |> mes("you're a reliable and")
    |> mes("trustworthy person! Go")
    |> mes("and bring me 1 Mushroom")
    |> mes("Spore with my Fish Cake Soup!")
    |> close()
  end
end
