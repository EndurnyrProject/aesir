defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Object163178 do
  @moduledoc """
  A hidden passage returns the player to the Odin Shrine.

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
        map: "que_hugel",
        x: 163,
        y: 178,
        dir: 0,
        sprite: 139,
        name: "object",
        scope: :shared,
        unique_name: "object#3",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_odin, 0) == 22 do
      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Huh?")
        |> mes("What's happening?")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Waaaaahhhh!")
      |> close()
      |> set_char_var(:hg_odin, 23)
      |> warp("odin_tem03", 264, 260)
    else
      ctx
    end
  end
end
