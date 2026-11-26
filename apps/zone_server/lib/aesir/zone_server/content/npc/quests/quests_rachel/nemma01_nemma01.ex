defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Nemma01Nemma01 do
  @moduledoc """
  A hidden voice advances the sanctuary investigation.

  ## Behavior

  - Reveals Panno’s voice to adventurers investigating the temple.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_rachel",
        x: 170,
        y: 37,
        dir: 0,
        sprite: -1,
        name: "nemma01",
        scope: :shared,
        trigger: {5, 5}
      },
      %{
        map: "que_rachel",
        x: 175,
        y: 37,
        dir: 0,
        sprite: -1,
        name: "nemma02",
        scope: :shared,
        trigger: {5, 5}
      },
      %{
        map: "que_rachel",
        x: 180,
        y: 37,
        dir: 0,
        sprite: -1,
        name: "nemma03",
        scope: :shared,
        trigger: {5, 5}
      },
      %{
        map: "que_rachel",
        x: 165,
        y: 37,
        dir: 0,
        sprite: -1,
        name: "nemma04",
        scope: :shared,
        trigger: {5, 5}
      },
      %{
        map: "que_rachel",
        x: 160,
        y: 37,
        dir: 0,
        sprite: -1,
        name: "nemma05",
        scope: :shared,
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :ra_tem_q, 0) == 8 do
      ctx =
        ctx
        |> mes("[???]")
        |> mes("Only the goddess exists.")
        |> next()
        |> mes("[???]")
        |> mes("Everyone must be")
        |> mes("ready for her coming.")
        |> next()
        |> mes("[???]")
        |> mes("Izlude, my hometown,")
        |> mes("I have come to this")
        |> mes("place to build.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("!")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Th-that's Priestess")
      |> mes("Panno's voice! But isn't")
      |> mes("she just outside the door?")
      |> mes("What exactly was she saying?")
      |> set_char_var(:ra_tem_q, 9)
      |> close()
    else
      ctx
    end
  end
end
