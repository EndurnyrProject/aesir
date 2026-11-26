defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.ZdanBroad do
  @moduledoc """
  Controls the Z Gang hideout encounter.

  ## Behavior

  - Announces the intrusion, summons guards, and resets the hideout on timers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "z_agit",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#zdan_broad"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnTimer3000", ctx), do: ev_ontimer3000(ctx)
  def on_event("OnTimer5000", ctx), do: ev_ontimer5000(ctx)
  def on_event("OnTimer7000", ctx), do: ev_ontimer7000(ctx)
  def on_event("OnTimer9000", ctx), do: ev_ontimer9000(ctx)
  def on_event("OnTimer11000", ctx), do: ev_ontimer11000(ctx)
  def on_event("OnTimer13000", ctx), do: ev_ontimer13000(ctx)
  def on_event("OnTimer15000", ctx), do: ev_ontimer15000(ctx)
  def on_event("OnTimer18000", ctx), do: ev_ontimer18000(ctx)
  def on_event("OnTimer21000", ctx), do: ev_ontimer21000(ctx)
  def on_event("OnTimer300000", ctx), do: ev_ontimer300000(ctx)
  def on_event("OnTimer350000", ctx), do: ev_ontimer350000(ctx)
  @impl true
  def on_talk(ctx), do: ev_oninit(ctx)

  def ev_oninit(ctx) do
    ctx |> disablenpc("#zdan_broad") |> stopnpctimer()
  end

  def ev_onenable(ctx) do
    ctx
    |> enablenpc("#zdan_broad")
    |> initnpctimer()
    |> hideonnpc("Louis")
    |> hideonnpc("Martha")
    |> hideonnpc("Catfoii")
  end

  def ev_ondisable(ctx) do
    ctx |> disablenpc("#zdan_broad") |> stopnpctimer()
  end

  def ev_ontimer3000(ctx) do
    ctx
    |> killmonster("z_agit", "#ZGuard::OnMyMobDead")
    |> mapannounce(
      "z_agit",
      "Catfoii: Err? I heard something, meow! We must be under attack, meow!",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer5000(ctx) do
    mapannounce(
      ctx,
      "z_agit",
      "Louis: Hey, Martha! Are you the one who just got in?",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer7000(ctx) do
    mapannounce(
      ctx,
      "z_agit",
      "Martha: Louis, are you blind? I've been next to you this whole time! We'd better hide first.",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer9000(ctx) do
    mapannounce(
      ctx,
      "z_agit",
      "Louis: We have an intruder! Hey, Catfoii, what happened? Did you leave the entrance open?",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer11000(ctx) do
    mapannounce(
      ctx,
      "z_agit",
      "Catfoii: No, impossible, meow~! I have a photographic memory!",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer13000(ctx) do
    mapannounce(
      ctx,
      "z_agit",
      "Martha: Shut up, both of you! I don't know who you are, but you must have a lot of guts to mess with the Z Gang!",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer15000(ctx) do
    mapannounce(
      ctx,
      "z_agit",
      "Louis: Catfoii, summon the soldiers! This is an emergency! Stop the intruder!",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer18000(ctx) do
    mapannounce(
      ctx,
      "z_agit",
      "Catfoii: I haven't seen how strong they are, but... Meowkay. Guys, go out and fight!",
      1,
      "0xFFFF00"
    )
  end

  def ev_ontimer21000(ctx) do
    donpcevent(ctx, "#ZGuard::OnEnable")
  end

  def ev_ontimer300000(ctx) do
    ctx
    |> killmonster("z_agit", "#ZGuard::OnMyMobDead")
    |> donpcevent("#zdan_broad::OnDisable")
    |> set_server_temp_var("monster_zgang", 0)
    |> set_server_temp_var("door2", 0)
  end

  def ev_ontimer350000(ctx) do
    ctx
    |> mapwarp("z_agit", "moc_fild17", 209, 235)
    |> hideonnpc("Louis")
    |> hideonnpc("Martha")
    |> hideonnpc("Catfoii")
    |> set_server_temp_var("monster_zgang", 0)
    |> set_server_temp_var("door2", 0)
  end
end
