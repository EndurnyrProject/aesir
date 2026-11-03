defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.Npc135135 do
  @moduledoc """
  Hidden five-minute timer for the Close Confine training ground.

  ## Behavior

  - Announces the time limit when the round starts and warns at 20 and 5 seconds remaining.
  - At the limit, hides every Kienna, stops the movement timer, re-arms the arena entrance
    trigger and waiting room, and warps everyone on the map back to the Rogue Guild.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 2Spiritual Kid
    - DracoRPG
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @kiennas ~w(Kienna#1st Kienna#2nd Kienna#3rd Kienna#4th Kienna#5th Kienna#6th Kienna#7th Kienna#8th)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "#1st5min")
  def on_event("OnEnable", ctx), do: ctx |> enablenpc("#1st5min") |> initnpctimer()
  def on_event("OnDisable", ctx), do: ctx |> stopnpctimer() |> disablenpc("#1st5min")

  def on_event("OnTimer1000", ctx) do
    announce(
      ctx,
      "Welcome to the Close Confine Training Ground. You will be automatically teleported outside in 5 minutes."
    )
  end

  def on_event("OnTimer290000", ctx),
    do: announce(ctx, "You will be teleported outside in 20 seconds.")

  def on_event("OnTimer310000", ctx),
    do: announce(ctx, "You will be teleported outside in 5 seconds.")

  def on_event("OnTimer315000", ctx) do
    ctx = announce(ctx, "You are now being teleported outside.")

    @kiennas
    |> Enum.reduce(ctx, &disablenpc(&2, &1))
    |> donpcevent("#1stmove::OnDisable")
    |> enablenpc("#1strecog")
    |> donpcevent("Waiting Room#rogue10::OnEnable")
    |> stopnpctimer()
    |> mapwarp("prt_are01", "in_rogue", 264, 124)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp announce(ctx, message), do: mapannounce(ctx, "prt_are01", message, 1, "0x00ff00")
end
