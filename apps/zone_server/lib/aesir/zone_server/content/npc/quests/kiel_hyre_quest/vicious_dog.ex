defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.ViciousDog do
  @moduledoc """
  The vicious dog guards passage through the cottage.

  ## Behavior

  - Offers a touch-triggered choice to approach or flee.
  - Consumes one Pet Food to permit passage; otherwise chases the player downstairs.

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
        x: 181,
        y: 178,
        dir: 4,
        sprite: 81,
        name: "Vicious Dog",
        scope: :shared,
        unique_name: "Vicious Dog#khp1",
        trigger: {7, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: approach_dog(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp approach_dog(ctx) do
    {ctx, choice} =
      ctx
      |> mes("*Grrr~*")
      |> next()
      |> mes("^3355FFAn extremely vicious")
      |> mes("looking dog is glaring")
      |> mes("at you. Can you really")
      |> mes("pass by this creature")
      |> mes("without getting hurt?^000000")
      |> next()
      |> select(["March forward", "Run away"])

    case choice do
      1 ->
        if count_item(ctx, 537) >= 1 do
          offer_food(ctx)
        else
          chase_downstairs(ctx)
        end

      2 ->
        ctx
        |> mes("^3355FFLet's get out of here!^000000")
        |> close()
        |> warp("kh_vila", 126, 70)

      _ ->
        ctx
    end
  end

  defp offer_food(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFWait! Perhaps you can")
      |> mes("use food to soothe the")
      |> mes("savage beast. Why don't")
      |> mes("you feed it some of your Pet")
      |> mes("Food and see what happens?^000000")
      |> next()
      |> select(["Give Pet Food", "It won't work!"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou gingerly throw the")
        |> mes("Pet Food towards the dog.")
        |> mes("Its tail shakes violently as")
        |> mes("it devours the food. You'd")
        |> mes("better pass this dog now")
        |> mes("while you have the chance!^000000")
        |> delitem(537, 1)
        |> close()
        |> warp("kh_vila", 173, 182)

      2 ->
        chase_downstairs(ctx)

      _ ->
        ctx
    end
  end

  defp chase_downstairs(ctx) do
    ctx
    |> mes("^3355FFYou slowly approach")
    |> mes("the dog, but it won't")
    |> mes("stop snarling at you.")
    |> mes("You try to run past the")
    |> mes("dog, but it blocks all of")
    |> mes("your moves. What to do?^000000")
    |> next()
    |> mes("[Vicious Dog]")
    |> mes("BOW WOW!")
    |> mes("BOW WOW!")
    |> mes("BOW WOW WOW!")
    |> next()
    |> mes("^3355FFThe dog chased you")
    |> mes("downstairs like the")
    |> mes("suckah chump you are.^000000")
    |> close()
    |> warp("kh_vila", 126, 70)
  end
end
