defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Calabash do
  @moduledoc """
  The cottage calabash conceals an Old Bronze Key.

  ## Behavior

  - Offers inspection while the adventurer lacks the related keys and has not progressed beyond the cottage.
  - Checks inventory capacity and awards the key when the adventurer looks inside.

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
        x: 14,
        y: 55,
        dir: 0,
        sprite: 111,
        name: "Calabash",
        scope: :shared,
        unique_name: "Calabash#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if count_item(ctx, 7329) < 1 and count_item(ctx, 7516) < 1 and count_item(ctx, 7491) < 1 and
         get_char_var(ctx, :KielHyreQuest, 0) < 38 do
      if checkweight(ctx, [{7329, 1}]) == 0 do
        ctx
        |> mes("^3355FFThat's a nice looking")
        |> mes("calabash. You might even")
        |> mes("get something from it...")
        |> mes("But first you better get")
        |> mes("rid of all your extra weight.")
        |> mes("And by weight, I mean items.^000000")
        |> close()
      else
        inspect_calabash(ctx)
      end
    else
      ctx
      |> mes("^3355FFThis is the expensive")
      |> mes("looking calabash from")
      |> mes("which you've obtained")
      |> mes("the Old Bronze Key.")
      |> mes("It's useless to you now.^000000")
      |> close()
    end
  end

  defp inspect_calabash(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFIt's an expensive")
      |> mes("looking calabash--")
      |> mes("or in less fancy")
      |> mes("words, a ''gourd.''")
      |> mes("Would do you do?^000000")
      |> next()
      |> select(["Break Open Calabash", "Look Inside Calabash", "Ignore"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou can't break")
        |> mes("open that calabash...")
        |> mes("You're a hero, not a vandal.")
        |> mes("Now, if this act of vandalism")
        |> mes("can be considered an act of")
        |> mes("heroism, then it'd be okay.^000000")
        |> close()

      2 ->
        ctx
        |> mes("^3355FFYou tenderly place")
        |> mes("your hand into the")
        |> mes("calabash, and gently")
        |> mes("feel around with your")
        |> mes("fingers until you retrieve")
        |> mes("an Old Bronze Key.^000000")
        |> give_item(7329, 1)
        |> close()

      3 ->
        ctx
        |> mes("^3355FFThere's probably")
        |> mes("nothing inside anyway.^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
