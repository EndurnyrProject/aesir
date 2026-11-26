defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.SDance2116 do
  @moduledoc """
  Tracks the right-hand dance test marker.

  ## Behavior

  - Counts activations and advances the dance sequence when the player touches the marker.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in01",
        x: 21,
        y: 16,
        dir: 0,
        sprite: 139,
        name: "s_dance",
        scope: :shared,
        unique_name: "s_dance#right",
        trigger: {3, 1}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnUp", ctx), do: ev_onup(ctx)
  def on_event("OnReset", ctx), do: ev_onreset(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    donpcevent(ctx, "s_dance#right::OnDisable")
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc("s_dance#right") |> specialeffect(:summonslave)
  end

  def ev_ondisable(ctx) do
    disablenpc(ctx, "s_dance#right")
  end

  def ev_onup(ctx) do
    set_npc_var(ctx, "s_right", get_npc_var(ctx, "s_right", 0) + 1)
  end

  def ev_onreset(ctx) do
    set_npc_var(ctx, "s_right", 0)
  end

  def ev_ontouch(ctx) do
    ctx = soundeffect(ctx, "effect\\sign_right.wav", 1)

    case get_npc_var(ctx, "s_right", 0) do
      1 ->
        ctx
        |> donpcevent("Examiner#sd::OnUp")
        |> donpcevent("s_dance#right::OnDisable")

      step when step in [2, 4] ->
        advance_dance(ctx, "up")

      step when step in [3, 5, 6] ->
        advance_dance(ctx, "down")

      7 ->
        advance_dance(ctx, "cen")

      8 ->
        advance_dance(ctx, "left")

      _ ->
        ctx
    end
  end

  defp advance_dance(ctx, direction) do
    ctx
    |> donpcevent("Examiner#sd::OnUp")
    |> donpcevent("s_dance##{direction}::OnUp")
    |> donpcevent("s_dance##{direction}::OnEnable")
    |> donpcevent("s_dance#right::OnDisable")
  end
end
