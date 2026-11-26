defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Brisinsold2 do
  @moduledoc """
  Controls the time players can spend in Lowen's past.

  ## Behavior

  - Reveals the soldier and starts a timer when the encounter begins.
  - Warns players, returns them to Geffen, and resets the encounter when time expires.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god02",
        x: 1,
        y: 1,
        dir: 1,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#brisinsold2"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: reset_soldier(ctx)

  def on_event("OnSold2On", ctx) do
    ctx |> hideoffnpc("Soldier#2_brising") |> initnpctimer()
  end

  def on_event("OnTimer420000", ctx) do
    mapannounce(ctx, "que_god02", "Lowen's spirit is beginning to weaken...", 0, 7_396_315)
  end

  def on_event("OnTimer480000", ctx) do
    mapannounce(
      ctx,
      "que_god02",
      "Your presense in her past can't be maintained for much longer...",
      0,
      7_396_315
    )
  end

  def on_event("OnTimer540000", ctx) do
    mapannounce(
      ctx,
      "que_god02",
      "Lowen's spirit can't keep you in the past any longer.",
      0,
      7_396_315
    )
  end

  def on_event("OnTimer542000", ctx), do: return_players(ctx)
  def on_event("OnTimer550000", ctx), do: donpcevent(ctx, "#brisinsummon::OnReset")
  def on_event("OnTimer550500", ctx), do: stopnpctimer(ctx)

  @impl true
  def on_talk(ctx), do: reset_soldier(ctx)

  defp reset_soldier(ctx) do
    ctx
    |> hideonnpc("Soldier#2_brising")
    |> return_players()
  end

  defp return_players(ctx) do
    areawarp(ctx, "que_god02", 15, 125, 185, 131, "geffen", 120, 100)
  end
end
