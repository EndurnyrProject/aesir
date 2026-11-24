defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Timer13 do
  @moduledoc """
  Hidden countdown that reveals a Broken Sword blade piece once its trace is found.

  ## Behavior

  - Started by its trace when a player on the matching quest step steps on it.
  - Reveals the blade piece 3 seconds later; the revealed piece stops and hides it again.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "gon_dun01", x: 4, y: 1, dir: 0, sprite: -1, name: "timer1-3", scope: :shared}]

  @impl true
  def on_talk(ctx), do: reset(ctx)

  @impl true
  def on_event("OnInit", ctx), do: reset(ctx)

  def on_event("OnCommandOn", ctx) do
    ctx |> enablenpc("timer1-3") |> setnpctimer(0) |> startnpctimer()
  end

  def on_event("OnCommandOff", ctx) do
    ctx |> stopnpctimer() |> disablenpc("timer1-3")
  end

  def on_event("OnTimer3000", ctx), do: donpcevent(ctx, "#getitem1-3::OnCommandOn")

  defp reset(ctx) do
    ctx |> initnpctimer() |> stopnpctimer() |> disablenpc("timer1-3")
  end
end
