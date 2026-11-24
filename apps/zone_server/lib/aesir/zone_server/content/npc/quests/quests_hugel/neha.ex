defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Neha do
  @moduledoc """
  Neha is a customer in Cellette's Fish Cake Soup delivery quest.

  ## Behavior

  - Requests a whip before accepting the soup.
  - Accepts both items, spanks the player and advances the delivery quest.

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
    spawn: [%{map: "hugel", x: 76, y: 134, dir: 3, sprite: 101, name: "Neha", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    delivery = get_char_var(ctx, :hg_odeng, 0)

    cond do
      delivery == 1 and Rathena.truthy?(count_item(ctx, 584)) ->
        request_whip(ctx)

      delivery == 6 and Rathena.truthy?(count_item(ctx, 1960)) and
          Rathena.truthy?(count_item(ctx, 584)) ->
        accept_delivery(ctx)

      delivery == 6 ->
        remind_player(ctx)

      true ->
        greet(ctx)
    end
  end

  defp request_whip(ctx) do
    ctx =
      ctx
      |> mes("[Neha]")
      |> mes("Oh, you have a delivery")
      |> mes("from Cellette, hm? Hmpf!")
      |> mes("You're late! Don't you know")
      |> mes("this soup isn't good if it")
      |> mes("isn't steaming hot?")
      |> next()

    ctx =
      if sex(ctx) == 1 do
        ctx
        |> mes("[Neha]")
        |> mes("But... You're a handsome")
        |> mes("fellow, so I'll forgive you...")
        |> mes("On one condition. Bring me")
        |> mes("^FF00001 Whip^000000 with which to spank ")
        |> mes("you. You better hurry, boy, or")
        |> mes("I won't let you off that easy.")
      else
        ctx
        |> mes("[Neha]")
        |> mes("Yes, yes... You should")
        |> mes("be punished. You should be")
        |> mes("spanked. If you want to finish")
        |> mes("your delivery, then bring me")
        |> mes("^FF00001 Whip^000000 so that I can spank you")
        |> mes("for your impertinence, girl!")
      end

    ctx
    |> set_local(:i, 8064)
    |> complete_previous_quests()
    |> setquest(8068)
    |> set_char_var(:hg_odeng, 6)
    |> close()
  end

  defp greet(ctx) do
    ctx
    |> mes("[Neha]")
    |> mes("Oh ho ho ho ho ho~")
    |> mes("I just love cute little boys...")
    |> mes("But for some reason, it")
    |> mes("thrills me to torture them")
    |> mes("a little bit as well. Hoho~")
    |> close()
  end

  defp accept_delivery(ctx) do
    ctx
    |> mes("[Neha]")
    |> mes("Finally... My soup!")
    |> mes("And you brought me my Whip!")
    |> mes("Don't worry, I'll only give you")
    |> mes("just one hard spanking. It'll")
    |> mes("be over before you know it~")
    |> next()
    |> mes("[Neha]")
    |> mes("Ha!")
    |> next()
    |> mes("^3355FF*Slap*^000000")
    |> percent_heal(hp: -25, sp: 0)
    |> next()
    |> mes("[Neha]")
    |> mes("Heeyah!!")
    |> next()
    |> mes("^3355FF*SLAP*^000000")
    |> percent_heal(hp: -25, sp: 0)
    |> next()
    |> mes("[Neha]")
    |> mes("Ooh, did I accidentally")
    |> mes("whip you twice? Heh heh...")
    |> mes("Well, I'm satisfied. I'll go")
    |> mes("ahead and tell Celette that")
    |> mes("you did a good job... I hope")
    |> mes("you come deliver my soup again~")
    |> delitem(1960, 1)
    |> delitem(584, 1)
    |> set_char_var(:hg_odeng, 10)
    |> changequest(8068, 8072)
    |> close()
  end

  defp remind_player(ctx) do
    ctx
    |> mes("[Neha]")
    |> mes("^FF00001 Fish Cake Soup^000000...")
    |> mes("^FF00001 Whip^000000... Is that too")
    |> mes("much for a girl to ask?")
    |> mes("I'm hungry, and I want to")
    |> mes("hit somebody! What's wrong")
    |> mes("with that, huh? Now hurry up!")
    |> close()
  end

  defp complete_previous_quests(ctx) do
    if get_local(ctx, :i, 0) <= 8067 do
      ctx =
        if checkquest(ctx, get_local(ctx, :i, 0)) > -1 and
             checkquest(ctx, get_local(ctx, :i, 0)) < 2 do
          completequest(ctx, get_local(ctx, :i, 0))
        else
          ctx
        end

      ctx |> set_local(:i, get_local(ctx, :i, 0) + 1) |> complete_previous_quests()
    else
      ctx
    end
  end
end
