defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.TrainStationStaff do
  @moduledoc """
  Operates the train service from Einbroch to Einbech.

  ## Behavior

  - Charges 200 zeny and transfers paying passengers to Einbech.
  - Explains Einbroch's smog alert and the city's industrial air pollution.
  - Serves two train station placements through the same interaction.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 232,
        y: 272,
        dir: 3,
        sprite: 852,
        name: "Train Station Staff",
        scope: :shared,
        unique_name: "EinbrochTrain"
      },
      %{
        map: "einbroch",
        x: 252,
        y: 301,
        dir: 3,
        sprite: 852,
        name: "Train Station Staff",
        scope: :shared,
        unique_name: "Train Station Staff#ein2"
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
      |> mes("Trains to Einbech")
      |> mes("are always running")
      |> mes("so if you miss one,")
      |> mes("it's no problem.")
      |> next()
      |> mes("[Staff]")
      |> mes("The fare to board the")
      |> mes("train that runs the Einbroch")
      |> mes("to Einbech line is 200 zeny.")
      |> mes("Would you like to buy a ticket?")
      |> next()
      |> select(["Yes.", "No.", "About the Environment..."])

    case choice do
      1 -> buy_ticket(ctx)
      2 -> decline_ticket(ctx)
      3 -> explain_environment(ctx)
      _ -> ctx
    end
  end

  defp buy_ticket(ctx) do
    if zeny(ctx) > 199 do
      ctx
      |> mes("[Staff]")
      |> mes("Thank you")
      |> mes("very much.")
      |> mes("Have a safe trip.")
      |> mes("^333333*Ahem*^000000 All aboard!")
      |> close()
      |> pay_zeny(200)
      |> warp("einbech", 43, 215)
    else
      ctx
      |> mes("[Staff]")
      |> mes("I'm sorry, but this")
      |> mes("isn't enough zeny")
      |> mes("to pay the train fare.")
      |> close()
    end
  end

  defp decline_ticket(ctx) do
    ctx
    |> mes("[Staff]")
    |> mes("Very well, then.")
    |> mes("Please enjoy your")
    |> mes("stay in Einbroch.")
    |> close()
  end

  defp explain_environment(ctx) do
    ctx
    |> mes("[Staff]")
    |> mes("Einbroch is infamous for")
    |> mes("its air pollution, no doubt")
    |> mes("caused by the industrial")
    |> mes("facilities located here.")
    |> mes("It's really horrible...")
    |> next()
    |> mes("[Staff]")
    |> mes("Sometimes the air pollution")
    |> mes("gets so bad that it becomes")
    |> mes("hard to breathe. If you hear")
    |> mes("the Einbroch Smog Alert, you")
    |> mes("should find shelter immediately!")
    |> close()
  end
end
