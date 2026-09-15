defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.TrainStationStaff do
  @moduledoc """
  Sells train passage from Einbech to Einbroch.

  ## Behavior

  - Charges 200 zeny and warps paying passengers to Einbroch.
  - Refuses passage when the player cannot afford the fare.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 39,
        y: 215,
        dir: 5,
        sprite: 852,
        name: "Train Station Staff",
        scope: :shared,
        unique_name: "Train Station Staff#ein3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Staff]")
      |> mes("Welcome to")
      |> mes("the Train Station.")
      |> mes("The fare to take the")
      |> mes("train to Einbroch is")
      |> mes("200 zeny. Would")
      |> mes("you like to ride?")
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 -> board_train(ctx)
      2 -> decline_ride(ctx)
      _ -> ctx
    end
  end

  defp board_train(ctx) do
    if zeny(ctx) > 199 do
      ctx
      |> mes("[Staff]")
      |> mes("Thank you and")
      |> mes("we hope you enjoy")
      |> mes("the ride. All aboard!")
      |> close()
      |> pay_zeny(200)
      |> warp("einbroch", 226, 276)
    else
      ctx
      |> mes("[Staff]")
      |> mes("I'm sorry,")
      |> mes("but you don't")
      |> mes("have enough zeny")
      |> mes("to pay the train fare.")
      |> close()
    end
  end

  defp decline_ride(ctx) do
    ctx
    |> mes("[Staff]")
    |> mes("Please enjoy")
    |> mes("your stay here")
    |> mes("in Einbech.")
    |> close()
  end
end
