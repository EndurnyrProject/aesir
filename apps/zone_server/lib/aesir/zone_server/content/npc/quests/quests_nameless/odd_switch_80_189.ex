defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.OddSwitch80189 do
  @moduledoc """
  A hidden switch advances the Broken Diamond investigation.

  ## Behavior

  - Activating it advances the quest and hides both switches.

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
        map: "cmd_in02",
        x: 80,
        y: 189,
        dir: 0,
        sprite: 844,
        name: "Odd Switch",
        scope: :shared,
        unique_name: "Odd Switch#Switch2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :diamond_edq, 0) == 22 or get_char_var(ctx, :diamond_edq, 0) == 23 do
      ctx =
        ctx
        |> mes("^3355FFThere is a tiny")
        |> mes("switch on the ground")
        |> mes("under the boxes' shadows.^000000")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Was this here before?")
        |> mes("What happens if I press")
        |> mes("this teeny little switch?")
        |> next()
        |> mes("^3355FF*Click Click*^000000")
        |> next()
        |> changequest(3116, 3117)
        |> set_char_var(:diamond_edq, 24)

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("That sound...!")
      |> mes("Something happened,")
      |> mes("but what could it be?")
      |> close2()
      |> hideonnpc("Odd Switch#Switch1")
      |> hideonnpc("Odd Switch#Switch2")
    else
      ctx
    end
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Odd Switch#Switch2")
  end
end
