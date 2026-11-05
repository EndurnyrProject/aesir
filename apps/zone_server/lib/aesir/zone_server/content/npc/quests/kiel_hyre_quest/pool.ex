defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Pool do
  @moduledoc """
  The cottage pool conceals a button beneath its mossy floor.

  ## Behavior

  - Offers the lion statue handles after the poem clue is discovered.
  - Drains the pool with the left handle and lets the adventurer activate the hidden stair mechanism.

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
        map: "kh_vila",
        x: 39,
        y: 41,
        dir: 0,
        sprite: 111,
        name: "Pool",
        scope: :shared,
        unique_name: "Pool#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    poem_stage = get_char_var(ctx, :KHCottagePoem1, 0)
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      poem_stage < 3 and quest_stage < 30 ->
        ctx
        |> mes("^3355FFYou find a fancy pool")
        |> mes("filled with fresh water.^000000")
        |> close()

      poem_stage == 3 and quest_stage < 30 ->
        offer_handles(ctx)

      poem_stage > 3 or quest_stage >= 30 ->
        ctx
        |> mes("^3355FFThis is where you pressed")
        |> mes("the small button that caused")
        |> mes("some strange sound to come")
        |> mes("from the stairs near the hallway.")
        |> close()

      true ->
        ctx
    end
  end

  defp offer_handles(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou find a fancy pool")
      |> mes("filled with fresh water,")
      |> mes("along with a conscpicuous")
      |> mes("lion statue with two handles.^000000")
      |> next()
      |> select(["Pull Handles", "Cancel"])

    case choice do
      1 ->
        choose_handle(ctx)

      2 ->
        ctx
        |> mes("^3355FFYou decided not")
        |> mes("to pull any handles.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp choose_handle(ctx) do
    {ctx, handle} =
      ctx
      |> mes("Which handle would")
      |> mes("you like to pull first?")
      |> next()
      |> select(["Right Handle", "Left Handle"])

    case handle do
      1 ->
        ctx
        |> mes("^3355FFYou pull the right")
        |> mes("handle, causing water")
        |> mes("to gush out of the lion's")
        |> mes("mouth. It looks pretty cool~^000000")
        |> close()

      2 ->
        drain_pool(ctx)

      _ ->
        ctx
    end
  end

  defp drain_pool(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFAs soon as you pull the")
      |> mes("left handle, the water in")
      |> mes("the pool drains away. The")
      |> mes("pool empties, and you can")
      |> mes("see a layer of green moss")
      |> mes("covering the pool's bottom.^000000")
      |> next()
      |> select(["Ignore", "Investigate"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou decide that")
        |> mes("a pool is little more")
        |> mes("than a hole without")
        |> mes("any water to fill it.^000000")
        |> close()

      2 ->
        investigate_moss(ctx)

      _ ->
        ctx
    end
  end

  defp investigate_moss(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFAs you look through")
      |> mes("the wet moss at the")
      |> mes("bottom of the pool,")
      |> mes("you stumble upon a")
      |> mes("small, peculiar button.^000000")
      |> next()
      |> select(["Press button", "Don't Press Button"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou press the button,")
        |> mes("which seems to trigger")
        |> mes("a strange sound coming")
        |> mes("from the stairs at the hallway.^000000")
        |> set_char_var(:KHCottagePoem1, 4)
        |> close()

      2 ->
        ctx
        |> mes("^3355FFYou'd better not push")
        |> mes("this button. Your enemies")
        |> mes("must have hidden it carefully")
        |> mes("for you to find: it must be")
        |> mes("some sort of nefarious trap.^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
