defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Box107126 do
  @moduledoc """
  A locked cottage box contains a Green Keycard.

  ## Behavior

  - Exchanges the Old Bronze Key for the Green Keycard while the cottage search is active.
  - Describes the locked box or the previously collected keycard otherwise.

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
        x: 107,
        y: 126,
        dir: 0,
        sprite: 111,
        name: "Box",
        scope: :shared,
        unique_name: "Box#khp2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      count_item(ctx, 7329) < 1 and count_item(ctx, 7516) < 1 and count_item(ctx, 7491) < 1 and
          get_char_var(ctx, :KielHyreQuest, 0) < 38 ->
        ctx
        |> mes("^3355FFA solid box is laid")
        |> mes("on the floor in which")
        |> mes("a smaller, locked box")
        |> mes("has been placed inside.^000000")
        |> close()

      count_item(ctx, 7329) >= 1 and count_item(ctx, 7516) < 1 and count_item(ctx, 7491) < 1 and
          get_char_var(ctx, :KielHyreQuest, 0) < 38 ->
        offer_bronze_key(ctx)

      true ->
        ctx
        |> mes("^3355FFThis is the box from")
        |> mes("which you've obtained")
        |> mes("the Green Keycard.^000000")
        |> close()
    end
  end

  defp offer_bronze_key(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFA solid box is laid")
      |> mes("on the floor in which")
      |> mes("a smaller, locked box")
      |> mes("has been placed inside.")
      |> mes("Perhaps you can use your")
      |> mes("Old Bronze Key to unlock it.^000000")
      |> next()
      |> select(["Use Old Bronze Key", "No, it'll never work."])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYour hunch paid off!")
        |> mes("The Old Bronze Key really")
        |> mes("did unlock that box! You")
        |> mes("open the inner box and")
        |> mes("obtain the Green Keycard")
        |> mes("that was locked inside.")
        |> give_item(7516, 1)
        |> delitem(7329, 1)
        |> close()

      2 ->
        ctx
        |> mes("^3355FFWhat...?")
        |> mes("What? Using a key")
        |> mes("to unlock a lock?")
        |> mes("Come on, that's")
        |> mes("freakin' crazy talk!^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
