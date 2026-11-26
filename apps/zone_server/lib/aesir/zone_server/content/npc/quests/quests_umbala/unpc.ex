defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.Unpc do
  @moduledoc """
  An outdoor trigger concludes the domestic dispute quest.

  ## Behavior

  - The player can take or leave a leaf after the encounter.

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
        map: "umbala",
        x: 94,
        y: 181,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#unpc",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "#unpc")
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :um_wind, 0) == 5 do
      {ctx, choice} =
        ctx
        |> mes("^3355FFAs you realized what happened")
        |> mes("after being kicked out of the")
        |> mes("house, you see a leaf on the")
        |> mes("ground near where you're standing.^000000")
        |> next()
        |> select(["Take it.", "Leave it."])

      if choice == 1 do
        ctx = ctx |> close2() |> set_char_var(:um_wind, 0)

        ctx
        |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), 32768))
        |> give_item(610, 1)
        |> disablenpc("#unpc")
      else
        ctx = set_char_var(ctx, :um_wind, 0)

        ctx =
          set_char_var(ctx, :MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), 32768))

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I am not supposed to take")
          |> mes("what may belong to other people.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Yeah, I'm a such good person.")
        |> close2()
        |> disablenpc("#unpc")
      end
    else
      ctx
    end
  end
end
