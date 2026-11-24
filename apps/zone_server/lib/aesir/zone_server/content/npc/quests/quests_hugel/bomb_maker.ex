defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.BombMaker do
  @moduledoc """
  Boomer sells Marine Sphere Bottles during the rebellion quest.

  ## Behavior

  - Offers a bottle for 3,000 zeny when the player has enough carrying capacity.

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
    spawn: [
      %{map: "einbech", x: 208, y: 124, dir: 3, sprite: 851, name: "Bomb Maker", scope: :shared}
    ]

  @marine_sphere_bottle 7138

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :hg_tre, 0) != 54 ->
        ctx
        |> mes("[Boomer]")
        |> mes("Hey, what's up?")
        |> mes("I am a professional Marine Sphere Bottle maker.")
        |> mes("You can call me Boomer.")
        |> close()

      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("[Boomer]")
        |> mes("Hey, you look pretty heavy, huh?")
        |> mes("Do you want me to help you?")
        |> close()

      true ->
        offer_bottle(ctx)
    end
  end

  defp offer_bottle(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Boomer]")
      |> mes("Hey, what's up?")
      |> mes("I am a professional Marine Sphere Bottle maker.")
      |> mes("You can call me Boomer.")
      |> next()
      |> select(["Buy Marine Sphere Bottle.", "End conversation."])

    case choice do
      1 -> buy_bottle(ctx)
      2 -> ctx |> mes("[Boomer]") |> mes("Boom! Don't you need a bomb? Boom!") |> close()
      _ -> ctx
    end
  end

  defp buy_bottle(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Boomer]")
      |> mes("Heh, you want my Marine Sphere Bottles, huh?")
      |> mes("You know, my bomb never fail to blow things away.")
      |> mes("Do you want to cut a tunnel?")
      |> mes("You've got the right choice for the bomb here!")
      |> next()
      |> mes("[Boomer]")
      |> mes("One Marine Sphere Bottle is 3,000 zeny.")
      |> mes("You must understand that I am providing the bomb at such a low price")
      |> mes("considering its amazing performance!")
      |> mes("You will regret if you miss this chance. Hahaha!")
      |> next()
      |> select(["Buy.", "Cancel."])

    case choice do
      1 ->
        complete_purchase(ctx)

      2 ->
        ctx
        |> mes("[Boomer]")
        |> mes("I believe that you will end up coming back to me. Heheh.")
        |> close()

      _ ->
        ctx
    end
  end

  defp complete_purchase(ctx) do
    if zeny(ctx) < 3000 do
      ctx
      |> mes("[Boomer]")
      |> mes("Errr...You must have been so hurry to carry your wallet with you.")
      |> close()
    else
      ctx
      |> mes("[Boomer]")
      |> mes("Just make sure that you are not going to")
      |> mes("blow yourself away with this bomb, hahah!")
      |> pay_zeny(3000)
      |> give_item(@marine_sphere_bottle, 1)
      |> close()
    end
  end
end
