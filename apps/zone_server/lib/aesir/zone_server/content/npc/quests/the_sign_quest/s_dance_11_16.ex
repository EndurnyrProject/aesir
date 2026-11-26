defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.SDance1116 do
  @moduledoc """
  Controls the left marker in The Sign dance exam.

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
        x: 11,
        y: 16,
        dir: 0,
        sprite: 139,
        name: "s_dance",
        scope: :shared,
        unique_name: "s_dance#left",
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
    donpcevent(ctx, "s_dance#left::OnDisable")
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc("s_dance#left") |> specialeffect(:summonslave)
  end

  def ev_ondisable(ctx) do
    disablenpc(ctx, "s_dance#left")
  end

  def ev_onup(ctx) do
    set_npc_var(ctx, "s_left", get_npc_var(ctx, "s_left", 0) + 1)
  end

  def ev_onreset(ctx) do
    set_npc_var(ctx, "s_left", 0)
  end

  def ev_ontouch(ctx) do
    ctx = soundeffect(ctx, "effect\\sign_left.wav", 1)

    case get_npc_var(ctx, "s_left", 0) do
      step when step in [1, 2, 6] ->
        ctx
        |> donpcevent("Examiner#sd::OnUp")
        |> donpcevent("s_dance#right::OnUp")
        |> donpcevent("s_dance#right::OnEnable")
        |> donpcevent("s_dance#left::OnDisable")

      step when step in [3, 7] ->
        ctx
        |> donpcevent("Examiner#sd::OnUp")
        |> donpcevent("s_dance#down::OnUp")
        |> donpcevent("s_dance#down::OnEnable")
        |> donpcevent("s_dance#left::OnDisable")

      4 ->
        ctx
        |> donpcevent("Examiner#sd::OnUp")
        |> donpcevent("s_dance#left::OnDisable")

      5 ->
        ctx
        |> donpcevent("Examiner#sd::OnUp")
        |> donpcevent("s_dance#up::OnUp")
        |> donpcevent("s_dance#up::OnEnable")
        |> donpcevent("s_dance#left::OnDisable")

      _ ->
        ctx
    end
  end
end
