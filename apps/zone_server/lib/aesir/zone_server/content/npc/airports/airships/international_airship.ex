defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.InternationalAirship do
  @moduledoc """
  Operates the timed route for the international airship.

  ## Behavior

  - Announces departures, travel progress, and arrivals around the route.
  - Opens and closes the exits at Izlude, Juno, and Rachel.
  - Periodically enables the airship invasion event while completing a circuit.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: ctx
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer25000", ctx) do
    mapannounce(ctx, "airplane_01", "We are heading to Izlude.", 1, "0x00ff00")
  end

  def on_event("OnTimer50000", ctx) do
    mapannounce(ctx, "airplane_01", "We will arrive in Izlude shortly.", 1, "0x00ff00")
  end

  def on_event("OnTimer60000", ctx) do
    ctx
    |> set_server_temp_var("airplanelocation2", 1)
    |> donpcevent("#AirshipWarp-3::OnUnhide")
    |> donpcevent("#AirshipWarp-4::OnUnhide")
    |> mapannounce("airplane_01", "Welcome to Izlude. Have a safe trip.", 1, "0x00ff00")
  end

  def on_event("OnTimer70000", ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "We are currently in Izlude. The Airship will take off shortly.",
      1,
      "0x00ff00"
    )
  end

  def on_event("OnTimer80000", ctx) do
    ctx
    |> donpcevent("#AirshipWarp-3::OnHide")
    |> donpcevent("#AirshipWarp-4::OnHide")
    |> mapannounce(
      "airplane_01",
      "The Airship is now taking off. Our next destination is Juno.",
      1,
      "0x70dbdb"
    )
  end

  def on_event("OnTimer105000", ctx) do
    mapannounce(ctx, "airplane_01", "We are heading to Juno.", 1, "0x70dbdb")
  end

  def on_event("OnTimer130000", ctx) do
    mapannounce(ctx, "airplane_01", "We will arrive in Juno shortly.", 1, "0x70dbdb")
  end

  def on_event("OnTimer140000", ctx) do
    ctx
    |> set_server_temp_var("airplanelocation2", 2)
    |> donpcevent("#AirshipWarp-3::OnUnhide")
    |> donpcevent("#AirshipWarp-4::OnUnhide")
    |> mapannounce("airplane_01", "Welcome to Juno. Have a safe trip.", 1, "0x70dbdb")
  end

  def on_event("OnTimer150000", ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "We are currently in Juno. The Airship will leave shortly.",
      1,
      "0x70dbdb"
    )
  end

  def on_event("OnTimer160000", ctx) do
    ctx
    |> donpcevent("#AirshipWarp-3::OnHide")
    |> donpcevent("#AirshipWarp-4::OnHide")
    |> mapannounce(
      "airplane_01",
      "The Airship is leaving the ground. Our next destination is Rachel.",
      1,
      "0xFF8200"
    )
  end

  def on_event("OnTimer185000", ctx) do
    mapannounce(ctx, "airplane_01", "We are heading to Rachel.", 1, "0xFF8200")
  end

  def on_event("OnTimer210000", ctx) do
    mapannounce(ctx, "airplane_01", "We will arrive in Rachel shortly.", 1, "0xFF8200")
  end

  def on_event("OnTimer220000", ctx) do
    ctx
    |> set_server_temp_var("airplanelocation2", 0)
    |> donpcevent("#AirshipWarp-3::OnUnhide")
    |> donpcevent("#AirshipWarp-4::OnUnhide")
    |> mapannounce("airplane_01", "Welcome to Rachel. Have a safe trip.", 1, "0xFF8200")
  end

  def on_event("OnTimer230000", ctx) do
    mapannounce(
      ctx,
      "airplane_01",
      "We are currently in Rachel. The Airship will take off shortly.",
      1,
      "0xFF8200"
    )
  end

  def on_event("OnTimer240000", ctx) do
    ctx =
      ctx
      |> donpcevent("#AirshipWarp-3::OnHide")
      |> donpcevent("#AirshipWarp-4::OnHide")
      |> mapannounce(
        "airplane_01",
        "The Airship is now taking off. Our next destination is Izlude.",
        1,
        "0x00ff00"
      )
      |> stopnpctimer()

    completed_routes = get_npc_var(ctx, "moninv", 0) + 1
    ctx = set_npc_var(ctx, "moninv", completed_routes)

    restart_or_enable_invasion(ctx, completed_routes)
  end

  defp restart_or_enable_invasion(ctx, 7) do
    if Enum.random(1..3) == 3 do
      donpcevent(ctx, "Airship#airplane02::OnEnable")
    else
      ctx
      |> set_npc_var("moninv", 0)
      |> initnpctimer()
    end
  end

  defp restart_or_enable_invasion(ctx, _completed_routes), do: initnpctimer(ctx)
end
