defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.JupeGoto do
  @moduledoc """
  Offers passage to the second floor through a timed light portal.

  ## Behavior

  - Lets visitors accept or reject the portal before the timer expires.
  - Transfers visitors when the portal timer expires.

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
        map: "juperos_01",
        x: 100,
        y: 91,
        dir: 0,
        sprite: -1,
        name: "jupe_goto",
        scope: :shared,
        unique_name: "jupe_goto#1",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    ctx = todo(ctx, :initnpctimer, ["jupe_goto#1", 1])

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("^777777[", char_name(ctx, 0)), "]^000000"))
      |> mes("This light...")
      |> mes("It feels like...")
      |> mes("Its warmth is...")
      |> mes("Wrapping all over me...")
      |> next()
      |> select(["Ah, it's so nice...", "No! This is wrong!"])

    case choice do
      1 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("^777777[", char_name(ctx, 0)), "]^000000"))
        |> mes("Ahhhh...")
        |> mes("It feels like")
        |> mes("I'm floating...")
        |> specialeffect2(:lightsphere)
        |> close()
        |> stopnpctimer()
        |> warp("juperos_02", 128, 278)

      2 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("^777777[", char_name(ctx, 0)), "]^000000"))
        |> mes("N-No! This is")
        |> mes("wrong! Something")
        |> mes("weird's happening!")
        |> mes("I gotta get away!")
        |> close()
        |> stopnpctimer()
        |> warp("juperos_01", 96, 91)

      _ ->
        ctx
    end
  end

  def on_event("OnTimer10000", ctx) do
    ctx |> stopnpctimer() |> warp("juperos_02", 128, 278) |> donpcevent("jupe_goto#2::OnEnable")
  end

  @impl true
  def on_talk(ctx), do: ctx
end
