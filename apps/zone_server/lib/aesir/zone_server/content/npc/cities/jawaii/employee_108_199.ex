defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee108199 do
  @moduledoc """
  Offers access to Jawaii's Antique Room.

  ## Behavior

  - Charges 1,000 zeny before transferring a guest to the room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii",
        x: 108,
        y: 199,
        dir: 5,
        sprite: 74,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#antroom"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Pine Oran]")
      |> mes("Welcome to")
      |> mes("the Antique room.")
      |> next()
      |> mes("[Pine Oran]")
      |> mes("This room provides lovers with")
      |> mes("an atmosphere of plush elegance.")
      |> mes("Every comfort is provided for")
      |> mes("young couples in this room.")
      |> next()
      |> mes("[Pine Oran]")
      |> mes(
        "All the rooms may have the same basic structure, but each of them has their own unique interior to suit the tastes of different people."
      )
      |> next()
      |> mes("[Pine Oran]")
      |> mes(
        "If you would like to lodge here, it is required to pay a 1,000 zeny fee for each person before entering. Since you're here to make fond memories of your honeymoon,"
      )
      |> mes("you should stay in the nicest room.")
      |> next()
      |> mes("[Pine Oran]")
      |> mes(
        "Do not hesitate to let me know when you've decided on the Antique Room. Once you've made your choice,"
      )
      |> mes("I will guide you there.")
      |> next()
      |> select(["Use.", "Cancel."])

    case choice do
      1 -> open_antique_room(ctx)
      _ -> decline_antique_room(ctx)
    end
  end

  defp open_antique_room(ctx) do
    ctx = mes(ctx, "[Pine Oran]")

    if zeny(ctx) > 999 do
      ctx
      |> mes("Thank you")
      |> mes("for using")
      |> mes("our services.")
      |> mes("Please...")
      |> mes("Make yourself")
      |> mes("comfortable.")
      |> close()
      |> pay_zeny(1000)
      |> warp("jawaii_in", 129, 110)
    else
      ctx
      |> mes(
        "I am sorry, but you don't seem to have enough money. If it's alright, why don't you check your current funds and see what you can do"
      )
      |> mes("about this situation?")
      |> close()
    end
  end

  defp decline_antique_room(ctx) do
    ctx
    |> mes("[Pine Oran]")
    |> mes("Please...")
    |> mes("Take your time.")
    |> mes("There should be no rush")
    |> mes("when it comes to leisure.")
    |> close()
  end
end
