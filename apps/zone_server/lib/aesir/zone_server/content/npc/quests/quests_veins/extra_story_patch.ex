defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ExtraStoryPatch do
  @moduledoc """
  A privileged patch NPC adjusts the spy quest progress.

  ## Behavior

  - Allows an authorized player to set and inspect quest progress.

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
        map: "sec_in02",
        x: 10,
        y: 43,
        dir: 4,
        sprite: 809,
        name: "Extra Story Patch",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FGmNpc
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FGmNpc.call(ctx, [])

    {ctx, choice} =
      ctx |> mes("[Patch]") |> mes("Yeah, you can try.") |> next() |> select(["Now", "How many?"])

    ctx =
      if choice == 2 do
        {ctx, input} = input(ctx, :int)
        {_, value} = Rathena.input_int(input, 0, 1000)
        ctx = set_local(ctx, :input, value)
        set_char_var(ctx, :que_sch, get_local(ctx, :input, 0))
      else
        ctx
      end

    ctx = mes(ctx, " ")
    ctx |> mes(Rathena.concat("", get_char_var(ctx, :que_sch, 0))) |> close()
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
