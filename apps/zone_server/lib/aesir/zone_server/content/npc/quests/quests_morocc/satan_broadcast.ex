defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.SatanBroadcast do
  @moduledoc """
  Satan Morocc taunts adventurers during the encounter.

  ## Behavior

  - Timed map announcements stop when the broadcast is disabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "moc_fild21",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "Satan Broadcast",
        scope: :shared,
        unique_name: "Satan Broadcast#edq"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer5000", ctx), do: ev_ontimer5000(ctx)
  def on_event("OnTimer15000", ctx), do: ev_ontimer15000(ctx)
  def on_event("OnTimer25000", ctx), do: ev_ontimer25000(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Satan Broadcast#edq")
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc("Satan Broadcast#edq") |> initnpctimer()
  end

  def ev_ontimer5000(ctx) do
    mapannounce(
      ctx,
      "moc_fild21",
      "Satan Morocc: I'm very impressed by you weaklings.",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer15000(ctx) do
    mapannounce(
      ctx,
      "moc_fild21",
      "Satan Morocc: You may as well deal with all your regrets now. I shall snuff out your life soon!",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer25000(ctx) do
    ctx
    |> mapannounce(
      "moc_fild21",
      "Satan Morocc: It's only a matter of time until I get you, you worthless insects. Just a little while longer...",
      1,
      "0xFFFF00"
    )
    |> stopnpctimer()
  end

  def ev_ondisable(ctx) do
    ctx |> stopnpctimer() |> disablenpc("Satan Broadcast#edq")
  end
end
