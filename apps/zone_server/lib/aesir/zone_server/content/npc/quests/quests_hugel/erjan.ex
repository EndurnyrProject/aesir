defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Erjan do
  @moduledoc """
  Erjan is a customer in Cellette's Fish Cake Soup delivery quest.

  ## Behavior

  - Requests China before accepting the soup.
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
    spawn: [%{map: "hugel", x: 102, y: 161, dir: 3, sprite: 100, name: "Erjan", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    delivery = get_char_var(ctx, :hg_odeng, 0)

    cond do
      delivery == 4 and Rathena.truthy?(count_item(ctx, 584)) ->
        request_item(ctx)

      delivery == 9 and Rathena.truthy?(count_item(ctx, 584)) and
          Rathena.truthy?(count_item(ctx, 736)) ->
        accept_delivery(ctx)

      delivery == 9 ->
        remind_player(ctx)

      true ->
        greet(ctx)
    end
  end

  defp request_item(ctx) do
    ctx
    |> mes("[Erjan]")
    |> mes("Well, I thought you'd")
    |> mes("never come to deliver")
    |> mes("my Fish Cake Soup. You're")
    |> mes("awfully late, you know that?")
    |> mes("Still, the smell is just so appetizing, I can barely resist...")
    |> next()
    |> mes("[Erjan]")
    |> mes("Hm, but as the first son")
    |> mes("of the Franchefeschu family,")
    |> mes("I cannot eat this soup unless")
    |> mes("it is suitably prepared. Go!")
    |> mes("I command you to bring me")
    |> mes("the commoner's ^FF0000China^000000!")
    |> next()
    |> set_char_var(:hg_odeng, 9)
    |> changequest(8067, 8071)
    |> mes("[Erjan]")
    |> mes("Realize that I'm compromising")
    |> mes("with you by asking you to bring")
    |> mes("me regular China... I always")
    |> mes("enjoy my meals on the finest")
    |> mes("glass and tableware available.")
    |> mes("That's how we noblemen live~")
    |> close()
  end

  defp greet(ctx) do
    ctx
    |> mes("[Erjan]")
    |> mes("I am Erjan, first son of")
    |> mes("the noble Franchefeschu")
    |> mes("family. Commoner, if you")
    |> mes("do not have any business")
    |> mes("with me, then leave me be,")
    |> mes("and do whatever it is you do.")
    |> close()
  end

  defp accept_delivery(ctx) do
    ctx
    |> mes("[Erjan]")
    |> mes("Ah, so you've delivered")
    |> mes("my Fish Cake Soup with some")
    |> mes("proper China. Yes, this pleases")
    |> mes("me. Now, I may enjoy this meal")
    |> mes("in a manner befitting the")
    |> mes("Franchefeschu family.")
    |> next()
    |> mes("[Erjan]")
    |> mes("Although this China is")
    |> mes("below my standards, I also")
    |> mes("understand that this is the")
    |> mes("best you can do. Yes, to accept")
    |> mes("this is my... noblesse oblige.")
    |> next()
    |> mes("[Erjan]")
    |> mes("You are dismissed.")
    |> mes("Please take your leave,")
    |> mes("and return to Cellette")
    |> mes("with my noble thanks.")
    |> delitem(736, 1)
    |> delitem(584, 1)
    |> set_char_var(:hg_odeng, 10)
    |> changequest(8071, 8075)
    |> close()
  end

  defp remind_player(ctx) do
    ctx
    |> mes("[Erjan]")
    |> mes("Must I repeat myself?")
    |> mes("Bring me my ^FF0000Fish Cake Soup^000000")
    |> mes("with ^FF00001 China^000000 so that I may")
    |> mes("properly enjoy my meal.")
    |> close()
  end
end
