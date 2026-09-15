defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.JawEmOrder do
  @moduledoc """
  Triggers the Jawaii Tavern employees' group greeting.

  ## Behavior

  - Dispatches welcome events for married visitors and solo events otherwise.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if Rathena.truthy?(getpartnerid(ctx)) do
      dispatch_welcome_events(ctx)
    else
      dispatch_solo_events(ctx)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp dispatch_welcome_events(ctx) do
    ctx
    |> donpcevent("Employee#jaw8::OnWelcome")
    |> donpcevent("Employee#jaw7::OnWelcome")
    |> donpcevent("Employee#jaw6::OnWelcome")
    |> donpcevent("Employee#jaw5::OnWelcome")
    |> donpcevent("Employee#jaw4::OnWelcome")
    |> donpcevent("Employee#jaw3::OnWelcome")
    |> donpcevent("Employee#jaw2::OnWelcome")
    |> donpcevent("Employee#jaw1::OnWelcome")
  end

  defp dispatch_solo_events(ctx) do
    ctx
    |> donpcevent("Employee#jaw8::OnSolo")
    |> donpcevent("Employee#jaw7::OnSolo")
    |> donpcevent("Employee#jaw6::OnSolo")
    |> donpcevent("Employee#jaw5::OnSolo")
    |> donpcevent("Employee#jaw4::OnSolo")
    |> donpcevent("Employee#jaw3::OnSolo")
    |> donpcevent("Employee#jaw2::OnSolo")
    |> donpcevent("Employee#jaw1::OnSolo")
  end
end
