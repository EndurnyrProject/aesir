defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Gate do
  @moduledoc """
  Offers a timed return portal to the previous floor.

  ## Behavior

  - Lets visitors use or ignore the portal before the timer expires.
  - A visitor who has not answered after 10 seconds is sent to the second floor, and the
    portal hands over to its follow-up gate.

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
        map: "jupe_gate",
        x: 50,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "gate",
        scope: :shared,
        unique_name: "gate#start",
        trigger: {2, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    {ctx, choice} =
      ctx
      |> initnpctimer("gate#start", 1)
      |> mes("^3355FFIt's a Warp Portal")
      |> mes("that will teleport you")
      |> mes("to the previous floor.^000000")
      |> next()
      |> select(["Use it.", "Ignore it."])

    case choice do
      1 ->
        ctx
        |> specialeffect2(:lightsphere)
        |> close()
        |> stopnpctimer()
        |> warp("juperos_02", 130, 142)

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Not now!")
        |> mes("I can't leave yet!")
        |> close()
        |> stopnpctimer()
        |> warp("jupe_gate", 50, 168)

      _ ->
        ctx
    end
  end

  def on_event("OnTimer10000", ctx) do
    ctx |> warp("juperos_02", 128, 278) |> enablenpc("gate#start#2") |> disablenpc("gate#start")
  end

  @impl true
  def on_talk(ctx), do: ctx
end
