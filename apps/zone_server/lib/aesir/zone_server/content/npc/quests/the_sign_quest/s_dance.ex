defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.SDance do
  @moduledoc """
  Controls the up marker in The Sign dance exam.

  ## Behavior

  - Plays a sound and advances the exam when the marker is touched.
  - Enables the next marker according to the dance sequence.

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
        x: 16,
        y: 21,
        dir: 0,
        sprite: 139,
        name: "s_dance",
        scope: :shared,
        unique_name: "s_dance#up",
        trigger: {1, 3}
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
    disablenpc(ctx, "s_dance#up")
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc("s_dance#up") |> specialeffect(:summonslave)
  end

  def ev_ondisable(ctx) do
    disablenpc(ctx, "s_dance#up")
  end

  def ev_onup(ctx) do
    set_npc_var(ctx, "s_up", get_npc_var(ctx, "s_up", 0) + 1)
  end

  def ev_onreset(ctx) do
    set_npc_var(ctx, "s_up", 0)
  end

  def ev_ontouch(ctx) do
    ctx = soundeffect(ctx, "effect\\sign_up.wav", 1)

    case get_npc_var(ctx, "s_up", 0) do
      1 ->
        ctx
        |> donpcevent("Examiner#sd::OnUp")
        |> donpcevent("s_dance#up::OnDisable")

      2 ->
        ctx
        |> donpcevent("Examiner#sd::OnUp")
        |> donpcevent("s_dance#cen::OnUp")
        |> donpcevent("s_dance#cen::OnEnable")
        |> donpcevent("s_dance#up::OnDisable")

      step when step in [3, 5] ->
        ctx
        |> donpcevent("Examiner#sd::OnUp")
        |> donpcevent("s_dance#right::OnUp")
        |> donpcevent("s_dance#right::OnEnable")
        |> donpcevent("s_dance#up::OnDisable")

      4 ->
        ctx
        |> donpcevent("Examiner#sd::OnUp")
        |> donpcevent("s_dance#down::OnUp")
        |> donpcevent("s_dance#down::OnEnable")
        |> donpcevent("s_dance#up::OnDisable")

      _ ->
        ctx
    end
  end
end
