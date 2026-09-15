defmodule Aesir.ZoneServer.Content.Npc.Cities.Yuno.JunoSage do
  @moduledoc """
  Discusses Apocalypse and occasionally offers a costly choice of herbs.

  ## Behavior

  - Usually describes the corrupted guardian Apocalypse.
  - On a rare roll, offers a Red Herb or Blue Herb to players carrying at least 5,000 zeny.
  - Charges 5,000 zeny and warps the player according to the chosen herb.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 165,
        y: 111,
        dir: 4,
        sprite: 123,
        name: "Juno Sage",
        scope: :shared,
        unique_name: "Juno Sage#juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Le Morpheus]")

    if Enum.random(1..50) == 25 do
      offer_herbs(ctx)
    else
      explain_apocalypse(ctx)
    end
  end

  defp offer_herbs(ctx) do
    if zeny(ctx) > 4_999 do
      {ctx, choice} =
        ctx
        |> mes("Look in my hand. I am holding two different kinds of herbs.")
        |> next()
        |> mes("[Le Morpheus]")
        |> mes(
          "One is a ^3355FFBlue Herb^000000 which will make you forget about reality and keep you in this virtual reality^000000."
        )
        |> next()
        |> mes("[Le Morpheus]")
        |> mes(
          "The other is a ^FF3355Red Herb^000000 which will reveal to you what is true and real."
        )
        |> next()
        |> mes("[Le Morpheus]")
        |> mes(
          "Whichever one you choose, you must spend ^3355FF5,000 zeny^000000. Now, please select one."
        )
        |> next()
        |> select(["Choose ^FF3355Red Herb^000000", "Choose ^3355FFBlue Herb^000000."])

      if choice == 1 do
        choose_red_herb(ctx)
      else
        choose_blue_herb(ctx)
      end
    else
      ctx
      |> mes(
        "Hmm. I'm sorry to say you just missed a fortunate chance. However, I can tell you don't have enough wealth to bring this fortune to fruition."
      )
      |> close()
    end
  end

  defp choose_red_herb(ctx) do
    ctx
    |> mes("[Le Morpheus]")
    |> mes("As you have chosen, you will forget everything, and remain in this virtual reality.")
    |> pay_zeny(5_000)
    |> give_item(507, 1)
    |> close()
    |> warp("prontera", 182, 206)
  end

  defp choose_blue_herb(ctx) do
    ctx
    |> mes("[Le Morpheus]")
    |> mes("You will see the truth.")
    |> pay_zeny(5_000)
    |> give_item(510, 1)
    |> close()
    |> warp("pay_dun03", 200, 222)
  end

  defp explain_apocalypse(ctx) do
    ctx
    |> mes("^3355FFApocalypse^000000...")
    |> mes("It is the name of an android that used to guard Juno long ago.")
    |> next()
    |> mes("[Le Morpheus]")
    |> mes(
      "Because its artificial intelligence has corrupted over the years, it can no longer distinguish comrades from enemies. Sadly, that android is nothing but a mindless monster now."
    )
    |> close()
  end
end
