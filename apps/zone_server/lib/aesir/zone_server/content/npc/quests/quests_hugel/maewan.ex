defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Maewan do
  @moduledoc """
  Maewan is a customer in Cellette's Fish Cake Soup delivery quest.

  ## Behavior

  - Requests a Bookclip in Memory before accepting the soup.
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
    spawn: [%{map: "hugel", x: 87, y: 139, dir: 3, sprite: 86, name: "Maewan", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    delivery = get_char_var(ctx, :hg_odeng, 0)

    cond do
      delivery == 2 and Rathena.truthy?(count_item(ctx, 584)) ->
        request_item(ctx)

      delivery == 7 and Rathena.truthy?(count_item(ctx, 584)) and
          Rathena.truthy?(count_item(ctx, 7015)) ->
        accept_delivery(ctx)

      delivery == 7 ->
        remind_player(ctx)

      true ->
        greet(ctx)
    end
  end

  defp request_item(ctx) do
    ctx
    |> mes("[Maewan]")
    |> mes("Oh, finally, I've been")
    |> mes("waiting for my order of")
    |> mes("Fish Cake Soup from Cellette!")
    |> mes("Aaaah, it smells oh so delicious~")
    |> next()
    |> mes("[Maewan]")
    |> mes("Argh, but you're late!")
    |> mes("This is your fault, you")
    |> mes("know that, right? Well,")
    |> mes("it's not a big deal, but")
    |> mes("I can forgive you if you")
    |> mes("help me with my collection.")
    |> next()
    |> mes("[Maewan]")
    |> mes("Just bring me")
    |> mes("1 Bookclip in Memory,")
    |> mes("alright? Oh, and don't")
    |> mes("eat my soup before")
    |> mes("you deliver it to me!")
    |> set_char_var(:hg_odeng, 7)
    |> changequest(8065, 8069)
    |> close()
  end

  defp greet(ctx) do
    ctx
    |> mes("[Maewan]")
    |> mes("I like to think of")
    |> mes("myself as a man of")
    |> mes("eclectic taste. I love")
    |> mes("collecting strange and")
    |> mes("unique items, and learning")
    |> mes("all sorts of new things~")
    |> close()
  end

  defp accept_delivery(ctx) do
    ctx
    |> mes("[Maewan]")
    |> mes("Great, you really brought")
    |> mes("me a Bookclip in Memory!")
    |> mes("Yes, this'll make a fine")
    |> mes("addition to my collection~")
    |> mes("Oh, and give me my soup.")
    |> mes("Thanks again for delivering~")
    |> delitem(584, 1)
    |> delitem(7015, 1)
    |> set_char_var(:hg_odeng, 10)
    |> changequest(8069, 8073)
    |> close()
  end

  defp remind_player(ctx) do
    ctx
    |> mes("[Maewan]")
    |> mes("I know it sounds unfair")
    |> mes("of me to ask you to bring")
    |> mes("^FF00001 Bookclip in Memory^000000 with")
    |> mes("my ^FF0000Fish Cake Soup^000000, but well...")
    |> next()
    |> mes("[Maewan]")
    |> mes("I'd feel left out if")
    |> mes("I didn't do it. I know")
    |> mes("all of Cellette's other")
    |> mes("customers are asking the")
    |> mes("people delivering their soup")
    |> mes("for all sorts of crazy things.")
    |> close()
  end
end
