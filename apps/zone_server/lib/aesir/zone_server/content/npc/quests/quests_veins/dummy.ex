defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Dummy do
  @moduledoc """
  A training dummy lets soldiers practice their attack orders.

  ## Behavior

  - Advances training after ten attacks and resets it if struck again.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "thor_camp",
        x: 150,
        y: 65,
        dir: 3,
        sprite: 111,
        name: "Dummy",
        scope: :shared,
        unique_name: "VeinsDummy",
        hidden_name: "1"
      },
      %{
        map: "thor_camp",
        x: 156,
        y: 65,
        dir: 3,
        sprite: 111,
        name: "Dummy",
        scope: :shared,
        unique_name: "Dummy#2"
      },
      %{
        map: "thor_camp",
        x: 162,
        y: 65,
        dir: 3,
        sprite: 111,
        name: "Dummy",
        scope: :shared,
        unique_name: "Dummy#3"
      },
      %{
        map: "thor_camp",
        x: 150,
        y: 57,
        dir: 3,
        sprite: 111,
        name: "Dummy",
        scope: :shared,
        unique_name: "Dummy#4"
      },
      %{
        map: "thor_camp",
        x: 156,
        y: 57,
        dir: 3,
        sprite: 111,
        name: "Dummy",
        scope: :shared,
        unique_name: "Dummy#5"
      },
      %{
        map: "thor_camp",
        x: 162,
        y: 57,
        dir: 3,
        sprite: 111,
        name: "Dummy",
        scope: :shared,
        unique_name: "Dummy#6"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :aru_vol, 0) do
      19 ->
        ctx
        |> mes("^3355FFIt's a training dummy")
        |> mes("that looks like it can")
        |> mes("take a beating. Its chest")
        |> mes("is marked with the emblem")
        |> mes("of the Rune-Midgarts Kingdom.^000000")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Wow...")
        |> mes("They really hate the")
        |> mes("Rune-Midgarts Kingdom...")
        |> mes("(^333333Technically, I shouldn't")
        |> mes("be doing this. Isn't this")
        |> mes("considered treason?^000000)")
        |> next()
        |> mes("[Colonel Vito]")
        |> mes("I can't hear you,")
        |> mes("soldier! Make your")
        |> mes("voice loud and clear!")
        |> mes("Now... Execute attack!")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Yes, sir!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("One!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Two!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Three!!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Four!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Five!!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Six!!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Seven!!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Eight!!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Nine!")
        |> next()
        |> specialeffect(:hit2)
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Ten!")
        |> set_char_var(:aru_vol, 20)
        |> close()

      20 ->
        ctx = ctx |> mes("^3355FF*THUD*^000000") |> specialeffect(:hit2)

        ctx
        |> emotion(:huk, playerattached(ctx))
        |> next()
        |> mes("[Colonel Vito]")
        |> mes("Soldier...")
        |> mes("How many times")
        |> mes("did I order you to")
        |> mes("chop the dummy?")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("10 times, sir!")
        |> next()
        |> mes("[Colonel Vito]")
        |> mes("And how many times")
        |> mes("did you actually")
        |> mes("chop the dummy?")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("11 times, sir!")
        |> next()
        |> mes("[Colonel Vito]")
        |> mes("Unacceptable!")
        |> mes("Listen to your orders")
        |> mes("this time, and do it")
        |> mes("again properly!")
        |> set_char_var(:aru_vol, 19)
        |> close()

      _ ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
