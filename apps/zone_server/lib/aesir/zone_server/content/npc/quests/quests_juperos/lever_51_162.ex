defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Lever51162 do
  @moduledoc """
  Controls a temporary checkpoint portal.

  ## Behavior

  - Opens the portal when the checkpoint is not in use.

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
        map: "jupe_area2",
        x: 51,
        y: 162,
        dir: 0,
        sprite: 844,
        name: "Lever",
        scope: :shared,
        unique_name: "Lever#ufe2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTimer3000", ctx) do
    ctx |> enablenpc("Lever#ufe2") |> stopnpctimer()
  end

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFIt's a lever")
      |> mes("whose function")
      |> mes("is not known to you.^000000")
      |> next()
      |> select(["Pull.", "Cancel."])

    case choice do
      1 ->
        if get_server_temp_var(ctx, "JupreArea2InUse", 0) == 1 do
          close(ctx)
        else
          ctx
          |> initnpctimer()
          |> donpcevent("LeverWarp#ufe2::OnEnable")
          |> disablenpc("Lever#ufe2")
          |> close()
        end

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Pull this lever?")
        |> mes("I don't even know")
        |> mes("what will happen...")
        |> close()

      _ ->
        ctx
    end
  end
end
