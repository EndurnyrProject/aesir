defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Draweropener do
  @moduledoc """
  Temporarily switches the medicine drawer during Allen’s quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
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
        map: "hu_in01",
        x: 1,
        y: 1,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#DrawerOpener"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer1000", ctx), do: ev_ontimer1000(ctx)
  def on_event("OnTimer4500", ctx), do: ev_ontimer4500(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "#DrawerOpener")
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc("#DrawerOpener") |> initnpctimer()
  end

  def ev_ontimer1000(ctx) do
    ctx |> enablenpc("Upper Drawer#Second") |> disablenpc("Upper Drawer#First")
  end

  def ev_ontimer4500(ctx) do
    ctx
    |> enablenpc("Upper Drawer#First")
    |> disablenpc("Upper Drawer#Second")
    |> disablenpc("#DrawerOpener")
    |> stopnpctimer()
  end
end
