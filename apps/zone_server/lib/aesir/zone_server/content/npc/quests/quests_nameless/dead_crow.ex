defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.DeadCrow do
  @moduledoc """
  A dead crow provides a clue to the poison investigation.

  ## Behavior

  - Investigating the crow advances the quest and moves the player inside.

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
        map: "nameless_i",
        x: 127,
        y: 207,
        dir: 0,
        sprite: 111,
        name: "Dead Crow",
        scope: :shared,
        unique_name: "Dead Crow#Aru"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :aru_monas, 0) do
      progress when progress < 17 ->
        ctx |> mes("^3355FFThere is a dead crow on the ground.") |> close()

      17 ->
        investigate_crow(ctx)

      _ ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp investigate_crow(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThe sight of this ^32CD32dead")
      |> mes("crow^3355FF makes you feel")
      |> mes("uneasy for some reason.^000000")
      |> next()
      |> select(["Ignore", "Investigate"])

    if choice == 1 do
      ctx
      |> mes("^3355FFYou decide not to touch")
      |> mes("the animal's carcass.^000000")
      |> close()
    else
      examine_crow(ctx)
    end
  end

  defp examine_crow(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou notice some grass sap")
      |> mes("on the crow's beak, so it")
      |> mes("must have been nibbling on")
      |> mes("some grass. Some feathers")
      |> mes("are missing, revealing")
      |> mes("scaly, snake-like skin.^000000")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Wait...")
      |> mes("Did this grass...?")
      |> next()
      |> mes("^3355FFThis grass must be the")
      |> mes("main ingredient of the")
      |> mes("poison used to kill the")
      |> mes("Geoborg family princes.^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Looks like I just hit")
    |> mes("the jackpot. Huh?")
    |> mes("Someone behi--")
    |> next()
    |> mes("^3355FFA sharp, throbbing pain")
    |> mes("assails the back of your")
    |> mes("head as you fall into")
    |> mes("unconsciousness...^000000")
    |> set_char_var(:aru_monas, 18)
    |> close2()
    |> warp("nameless_in", 15, 60)
  end
end
