defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Brasilis.CrewmanBra2 do
  @moduledoc """
  Crewman who sails players from Alberta to Brasilis.

  ## Behavior

  - Quotes the round trip at 10,000 zeny, or 1,000 zeny for an active VIP.
  - Charges the fare and warps the player to Brasilis, or ends the
    conversation without charging when they cannot pay.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/brasilis.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 246,
        y: 82,
        dir: 3,
        sprite: 100,
        name: "Crewman",
        scope: :renewal,
        unique_name: "Crewman#bra2"
      },
      %{
        map: "alberta",
        x: 247,
        y: 115,
        dir: 3,
        sprite: 100,
        name: "Crewman",
        scope: :pre_renewal,
        unique_name: "Crewman#bra2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @vip_status_active 1

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Crewman]")
      |> mes("Hey, have you heard of a place called Brasilis?")
      |> mes(
        "It's a tropical city that's hot like the desert but also rainy. It is a very mysterious place."
      )
      |> next()
      |> mes("[Crewman]")
      |> mes("We recently found a new ocean route to get there easily.")
      |> quote_fare()
      |> next()
      |> select(["Take me to Brasilis!", "I'll stay here."])

    case answer do
      1 -> sail_to_brasilis(ctx)
      2 -> decline_offer(ctx)
      _ -> ctx
    end
  end

  defp quote_fare(ctx) do
    if Rathena.truthy?(get_char_var(ctx, :VIP_SCRIPT, 0)) do
      fare = if Rathena.truthy?(vip_status(ctx, @vip_status_active)), do: 1000, else: 10_000

      ctx
      |> set_local(:cost, fare)
      |> mes("It's just 10,000 zeny for a round trip, and 1,000 for VIP! So do you want to go?")
    else
      ctx
      |> set_local(:cost, 10_000)
      |> mes("It's just 10,000 zeny for a round trip! So do you want to go?")
    end
  end

  defp sail_to_brasilis(ctx) do
    fare = get_local(ctx, :cost, 0)

    if zeny(ctx) < fare do
      ctx
      |> mes("[Crewman]")
      |> mes("I said #{insert_comma(ctx, fare)} zeny.")
      |> close()
    else
      ctx
      |> mes("[Crewman]")
      |> mes("Cool~!! Let's go~!")
      |> pay_zeny(fare)
      |> close()
      |> warp("brasilis", 314, 60)
    end
  end

  defp decline_offer(ctx) do
    ctx
    |> mes("[Crewman]")
    |> mes("Well if you're ever interested, let me know and I can take you there.")
    |> close()
  end
end
