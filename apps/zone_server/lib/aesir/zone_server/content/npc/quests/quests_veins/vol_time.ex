defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.VolTime do
  @moduledoc """
  Coordinates a timed exchange between Karlum and Lamir.

  ## Behavior

  - Announces their conversation and switches guard NPCs as the timer ends.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "ra_temin", x: 5, y: 5, dir: 3, sprite: 844, name: "vol_time", scope: :shared}]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer10000", ctx), do: ev_ontimer10000(ctx)
  def on_event("OnTimer15000", ctx), do: ev_ontimer15000(ctx)
  def on_event("OnTimer20000", ctx), do: ev_ontimer20000(ctx)
  def on_event("OnTimer30000", ctx), do: ev_ontimer30000(ctx)
  def on_event("OnTimer35000", ctx), do: ev_ontimer35000(ctx)
  def on_event("OnTimer40000", ctx), do: ev_ontimer40000(ctx)
  def on_event("OnTimer45000", ctx), do: ev_ontimer45000(ctx)
  def on_event("OnTimer50000", ctx), do: ev_ontimer50000(ctx)
  def on_event("OnTimer55000", ctx), do: ev_ontimer55000(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    stopnpctimer(ctx)
  end

  def ev_onenable(ctx) do
    ctx |> initnpctimer() |> enablenpc("Rachel Guard#vol1_1")
  end

  def ev_ontimer10000(ctx) do
    mapannounce(
      ctx,
      "ra_temin",
      "Guard Karlum: Lamir! It's Karlum! Your love is here!",
      1,
      "0xFFCE00"
    )
  end

  def ev_ontimer15000(ctx) do
    mapannounce(ctx, "ra_temin", "Lamir: Karlum? What are you doing here?", 1, "0xFFCE00")
  end

  def ev_ontimer20000(ctx) do
    mapannounce(
      ctx,
      "ra_temin",
      "Guard Karlum: Lamir, you can stop pretending now. I've come to realize that your coldness masks your love~",
      1,
      "0xFFCE00"
    )
  end

  def ev_ontimer30000(ctx) do
    mapannounce(
      ctx,
      "ra_temin",
      "Lamir: What are you talking about? Sorry, Karlum, but I don't have any special feelings for you.",
      1,
      "0xFFCE00"
    )
  end

  def ev_ontimer35000(ctx) do
    mapannounce(
      ctx,
      "ra_temin",
      "Guard Karlum: I know, it's embarrassing to confess your true feelings~",
      1,
      "0xFFCE00"
    )
  end

  def ev_ontimer40000(ctx) do
    mapannounce(
      ctx,
      "ra_temin",
      "Guard Karlum: However, I can't deny that your shyness is breaking my heart.",
      1,
      "0xFFCE00"
    )
  end

  def ev_ontimer45000(ctx) do
    mapannounce(
      ctx,
      "ra_temin",
      "Lamir: Karlum, when will you realize that I haven't, and won't ever fall in love with you?",
      1,
      "0xFFCE00"
    )
  end

  def ev_ontimer50000(ctx) do
    mapannounce(ctx, "ra_temin", "Guard Karlum: .............", 1, "0xFFCE00")
  end

  def ev_ontimer55000(ctx) do
    ctx
    |> mapannounce(
      "ra_temin",
      "Guard Karlum: Wha--? But I thought...? Huh, sorry. I should get going...",
      1,
      "0xFFCE00"
    )
    |> stopnpctimer()
    |> disablenpc("Rachel Guard#vol1_1")
    |> enablenpc("Rachel Guard#vol1")
  end
end
