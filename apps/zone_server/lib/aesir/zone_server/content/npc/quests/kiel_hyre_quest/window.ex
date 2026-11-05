defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Window do
  @moduledoc """
  Elly’s window offers a risky route into her room.

  ## Behavior

  - Allows climbing during the relevant quest stages.
  - A successful climb enters the room; a fall costs ten percent of maximum HP.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_fild08",
        x: 69,
        y: 185,
        dir: 0,
        sprite: 111,
        name: "Window",
        scope: :shared,
        unique_name: "Window#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 29 ->
        ctx
        |> mes("^3355FFYou can see a curtain")
        |> mes("decorated with a cute")
        |> mes("design through the")
        |> mes("window of this room,")
        |> mes("which is probably")
        |> mes("used by a young girl.^000000")
        |> close()

      quest_stage == 29 ->
        ctx
        |> mes("^3355FFThis must be Elly's room.")
        |> mes("It doesn't sound like anyone")
        |> mes("is inside, so she probably")
        |> mes("isn't back yet. For now, you")
        |> mes("should try to find what her")
        |> mes("grandfather left for her")
        |> mes("in their cottage's Study.^000000")
        |> close()

      quest_stage >= 30 and quest_stage <= 45 ->
        choose_route(ctx)

      true ->
        ctx
        |> mes("^3355FFYou can't go up into")
        |> mes("that open window.^000000")
        |> close()
    end
  end

  defp choose_route(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis slightly open window")
      |> mes("must lead into Elly's room.")
      |> mes("Although she asked you to")
      |> mes("find a ladder to enter her")
      |> mes("window, you probably won't")
      |> mes("find one. You might be able")
      |> mes("to climb up that water pipe...^000000")
      |> next()
      |> select(["Climb Water Pipe", "Find Another Way"])

    case choice do
      1 ->
        climb_pipe(ctx)

      2 ->
        ctx
        |> mes("^3355FFThere must be some")
        |> mes("other way to get into")
        |> mes("Elly's room, aside from")
        |> mes("climbing up this water pipe...^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp climb_pipe(ctx) do
    if Enum.random(1..3) == 2 do
      ctx
      |> mes("^3355FFYou climbed up the")
      |> mes("water pipe, and sneaked")
      |> mes("into Elly's room successfully.^000000")
      |> close()
      |> warp("kh_school", 185, 185)
    else
      ctx
      |> mes("^3355FFYou tried to climb")
      |> mes("the water pipe, but")
      |> mes("you ended up falling")
      |> mes("and bumping your head.^000000")
      |> percent_heal(hp: -10, sp: 0)
      |> close()
    end
  end
end
