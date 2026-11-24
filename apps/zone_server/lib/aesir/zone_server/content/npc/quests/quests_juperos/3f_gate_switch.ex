defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.M3fGateSwitch do
  @moduledoc """
  Controls the switches that open the third-floor gate.

  ## Behavior

  - Spawns three switches and opens the restricted area when all are destroyed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
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
        map: "juperos_02",
        x: 97,
        y: 70,
        dir: 0,
        sprite: -1,
        name: "3F Gate Switch",
        scope: :shared,
        unique_name: "3F Gate Switch#jupe"
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    initnpctimer(ctx)
  end

  def on_event("OnReset", ctx) do
    killmonster(ctx, "juperos_02", "3F Gate Switch#jupe::OnMyMobDead")
  end

  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("3F Gate Switch#jupe") |> initnpctimer()
  end

  def on_event("OnTimer5000", ctx) do
    ctx
    |> set_npc_var("MyMobs", 3)
    |> summon_mob(
      mob_id: 1674,
      map: "juperos_02",
      at: {24, 275},
      name: "1st Gate Switch",
      event: "3F Gate Switch#jupe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1674,
      map: "juperos_02",
      at: {240, 29},
      name: "2nd Gate Switch",
      event: "3F Gate Switch#jupe::OnMyMobDead"
    )
    |> summon_mob(
      mob_id: 1674,
      map: "juperos_02",
      at: {282, 183},
      name: "3rd Gate Switch",
      event: "3F Gate Switch#jupe::OnMyMobDead"
    )
    |> stopnpctimer()
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    cond do
      get_npc_var(ctx, "MyMobs", 0) == 2 ->
        mapannounce(ctx, "juperos_02", "Who are you to come here?", 1, "0xFF0000")

      get_npc_var(ctx, "MyMobs", 0) == 1 ->
        mapannounce(
          ctx,
          "juperos_02",
          "Have you come seeking Juperos?! It no longer exists...",
          1,
          "0xFF0000"
        )

      get_npc_var(ctx, "MyMobs", 0) == 0 ->
        ctx
        |> mapannounce(
          "juperos_02",
          "Have you come to see me? Fine! Find me first!",
          1,
          "0xFF0000"
        )
        |> specialeffect2(:screen_quake)
        |> soundeffectall("earth_quake.wav", 0)
        |> disablenpc("3F Gate Switch#jupe")
        |> donpcevent("Restricted Area#jupe::OnEnable")

      true ->
        ctx
    end
  end
end
