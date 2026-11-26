defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.Npc do
  @moduledoc """
  A house entrance triggers the domestic dispute scene.

  ## Behavior

  - The scene advances the quest and sends the player outside.

  ## Credits

  - Original from rAthena, authors and Contributors
    - sabernet09
    - rAthena Team
    - x[tsk]
    - Lupus
    - PoW
    - Evera
    - SinSloth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "um_in",
        x: 141,
        y: 46,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#!@#$%",
        trigger: {8, 8}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "#!@#$%")
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :um_wind, 0) == 4 do
      ctx
      |> set_char_var(:um_wind, 5)
      |> mes("^3355FFAs you enter the house")
      |> mes("you happen to witness")
      |> mes("Phrenetan beating a guy")
      |> mes("mercilessly.^000000")
      |> next()
      |> emotion(:fret)
      |> mes("[Phrenetan]")
      |> mes("Umbaumbaumbaumbah!")
      |> mes("Umbaumbahumbah!!")
      |> mes("Umbaumbahumbah!!!!!!")
      |> next()
      |> mes("^3355FFYou were kicked out of the house")
      |> mes("by Phrenetan.^000000")
      |> next()
      |> enablenpc("#unpc")
      |> disablenpc("#!@#$%")
      |> warp("umbala", 94, 181)
    else
      ctx
    end
  end
end
