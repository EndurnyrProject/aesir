defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Pot do
  @moduledoc """
  This boiling pot supplies steam for loosening the cottage map’s glue.

  ## Behavior

  - Offers the pot after the map clue is discovered and advances the poem puzzle when taken.

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
        x: 33,
        y: 184,
        dir: 0,
        sprite: 111,
        name: "Pot",
        scope: :shared,
        unique_name: "Pot#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    poem_stage = get_char_var(ctx, :KHCottagePoem1, 0)

    cond do
      poem_stage < 1 ->
        ctx
        |> mes("^3355FFYou've found a pot")
        |> mes("filled with boiling,")
        |> mes("steaming liquid.^000000")
        |> close()

      poem_stage == 1 ->
        offer_pot(ctx)

      poem_stage > 1 or get_char_var(ctx, :KielHyreQuest, 0) >= 30 ->
        ctx
        |> mes("^3355FFThis is where you")
        |> mes("picked up the pot filled")
        |> mes("with steaming hot liquid.^000000")
        |> close()

      true ->
        ctx
    end
  end

  defp offer_pot(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou've found a pot")
      |> mes("filled with boiling,")
      |> mes("steaming liquid.")
      |> mes("Steam... That you could")
      |> mes("use to loosen the glue on")
      |> mes("the map... You're a genius!^000000")
      |> next()
      |> select(["Try it.", "That? That won't work!"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou picked up the")
        |> mes("boiling pot, but")
        |> mes("slightly burned your")
        |> mes("hands by accident.")
        |> set_char_var(:KHCottagePoem1, 2)
        |> close()

      2 ->
        ctx
        |> mes("^3355FFNo, no...")
        |> mes("We'd better try")
        |> mes("something else.^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
