defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Packidentity do
  @moduledoc """
  A package reveals the cargo after the second attack.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airplane_01",
        x: 99,
        y: 47,
        dir: 3,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#packidentity",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  end

  def on_event("OnEnter", ctx) do
    ev_onenter(ctx)
  end

  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  end

  def on_event("OnTimer120000", ctx) do
    ev_ontimer120000(ctx)
  end

  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "#packidentity")
  end

  def ev_onenter(ctx) do
    ctx |> initnpctimer() |> enablenpc("#packidentity")
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :lhz_rekenber, 0) == 19 do
      ctx =
        ctx
        |> mes("^3355FFYou peek through the")
        |> mes("slit in the wrapping")
        |> mes("that is covering one")
        |> mes("of the packages.^000000")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Oh... my God!")
      |> mes("These are... These are")
      |> mes("weapons of mass destruction.")
      |> mes("There's even parts for assembling guardians, the kinds that usually")
      |> mes("defend those Guild Castles...")
      |> close2()
      |> donpcevent("Man#Lyozien::OnEnter")
      |> donpcevent("#packidentity::OnInit")
      |> stopnpctimer()
    else
      ev_ontimer120000(ctx)
    end
  end

  def ev_ontimer120000(ctx) do
    ctx
    |> donpcevent("Man#Lyozien::OnEnter")
    |> donpcevent("#packidentity::OnInit")
    |> stopnpctimer()
  end
end
