defmodule Aesir.ZoneServer.Content.Npc.Cities.Louyang.FriendlyLookingLady do
  @moduledoc """
  Operates the paid elevator to Luoyang's Observation Tower.

  ## Behavior

  - Explains the tower's history and elevator service.
  - Charges 500 zeny before transferring visitors to the tower.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vidar
    - Mass Zero
    - Dino9021
    - Celest
    - MasterOfMuppets
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in01",
        x: 25,
        y: 23,
        dir: 5,
        sprite: 817,
        name: "Friendly Looking Lady",
        scope: :shared,
        unique_name: "Friendly Looking Lady#lo"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hong Miao]")
      |> mes("Welcome.")
      |> next()
      |> mes("[Hong Miao]")
      |> mes("This is an elevator which leads")
      |> mes(
        "to the Observation Tower. We are providing you a safe and fast transfer service for an affordable fee. Would you like to use this service?"
      )
      |> next()
      |> select(["Information.", "Yes.", "Maybe next time."])

    case choice do
      1 -> explain_tower(ctx)
      2 -> use_elevator(ctx)
      3 -> decline_elevator(ctx)
      _ -> ctx
    end
  end

  defp explain_tower(ctx) do
    ctx
    |> mes("[Hong Miao]")
    |> mes(
      "After many suggestions and proposals were sent to the Luoyang tourism office, the Observation Tower was built so tourists can enjoy the sights."
    )
    |> next()
    |> mes("[Hong Miao]")
    |> mes("Due to the geographical")
    |> mes(
      "features of Luoyang, it's difficult to enjoy the breath taking view that our land has to offer."
    )
    |> next()
    |> mes("[Hong Miao]")
    |> mes(
      "You can come up to the tower by taking the elevator right here. We are providing this quick and safe transfer service for 500 zeny per person."
    )
    |> close()
  end

  defp use_elevator(ctx) do
    if zeny(ctx) < 500 do
      ctx
      |> mes("[Hong Miao]")
      |> mes(
        "I'm sorry, but you do not have enough zeny. I hope you'll come back later to enjoy the Observation Tower. Have a good day."
      )
      |> close()
    else
      ctx
      |> mes("[Hong Miao]")
      |> mes("Thank you for your patronage.")
      |> mes("We are trying to provide you with the best of service. Please")
      |> mes("come again.")
      |> next()
      |> pay_zeny(500)
      |> warp("lou_in01", 17, 19)
    end
  end

  defp decline_elevator(ctx) do
    ctx
    |> mes("[Hong Miao]")
    |> mes("Please come")
    |> mes("back later.")
    |> mes("Have a good day.")
    |> close()
  end
end
