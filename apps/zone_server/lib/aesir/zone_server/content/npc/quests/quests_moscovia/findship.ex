defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Findship do
  @moduledoc """
  A shipboard trigger reveals Whale Island during the voyage.

  ## Behavior

  - Enables a timed encounter and advances the quest when the player approaches.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_ship",
        x: 81,
        y: 110,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#findship",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer300000", ctx), do: ev_ontimer300000(ctx)
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_onenable(ctx)
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc("#findship") |> initnpctimer()
  end

  def ev_ontimer300000(ctx) do
    ctx |> stopnpctimer() |> ev_oninit()
  end

  def ev_oninit(ctx) do
    ctx |> set_server_temp_var("mos1_edq", 0) |> disablenpc("#findship")
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :mos_whale_edq, 0) == 12 do
      ctx = ctx |> mes("seeewaaaaaaaaaaa") |> next() |> mes("[Mr. Ibanoff]")

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("Hey ", char_name(ctx, 0)), "! Look!"))
        |> mes("It's dangerous! Hide! Hurry!")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("That... that is...")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Something... something is rising...")
        |> next()
        |> mes("[Mr. Ibanoff]")

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("Watch out! ", char_name(ctx, 0)), "!"))
        |> mes("Ah... That... That is... What...")
        |> set_char_var(:mos_whale_edq, 13)

      ctx =
        if Rathena.truthy?(isbegin_quest(ctx, 18108)) do
          changequest(ctx, 18108, 18109)
        else
          ctx
        end

      ctx |> close2() |> warp("mosk_fild01", 95, 93)
    else
      ctx
    end
  end
end
