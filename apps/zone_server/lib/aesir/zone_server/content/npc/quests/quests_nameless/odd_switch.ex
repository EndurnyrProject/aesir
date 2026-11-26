defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.OddSwitch do
  @moduledoc """
  A hidden switch reveals another switch during the jewel investigation.

  ## Behavior

  - Hides itself and reveals the other switch when pressed at the appropriate quest stage.

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
        x: 69,
        y: 196,
        dir: 0,
        sprite: 844,
        name: "Odd Switch",
        scope: :shared,
        unique_name: "Odd Switch#Switch1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :diamond_edq, 0) == 22 or get_char_var(ctx, :diamond_edq, 0) == 23 do
      ctx =
        ctx
        |> mes("^3355FFThere is a tiny")
        |> mes("switch on the ground")
        |> mes("near the whiskey barrels.^000000")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Was this here before?")
        |> mes("What happens if I press")
        |> mes("this teeny little switch?")
        |> next()
        |> hideoffnpc("Odd Switch#Switch2")
        |> mes("^3355FF*Click Click*^000000")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("That sound...!")
      |> mes("Something happened,")
      |> mes("but what could it be?")
      |> hideonnpc("Odd Switch#Switch1")
      |> close()
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Odd Switch#Switch1")
  end
end
