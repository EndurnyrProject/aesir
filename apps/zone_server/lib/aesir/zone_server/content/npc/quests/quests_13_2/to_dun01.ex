defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.ToDun01 do
  @moduledoc """
  Offers entry through the tree roots to the underground cave.

  ## Behavior

  - Quest progress controls the entrance dialogue and whether entry is possible.
  - Entering costs HP and advances the quest on the first visit.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_fild01",
        x: 375,
        y: 109,
        dir: 0,
        sprite: -1,
        name: "to_dun01",
        scope: :shared,
        unique_name: "to_dun01#ep13_2",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: enter_roots(ctx)

  @impl true
  def on_talk(ctx), do: enter_roots(ctx)

  defp enter_roots(ctx) do
    progress = get_char_var(ctx, :ep13_mdrama, 0)

    cond do
      progress == 5 ->
        first_visit(ctx)

      progress > 5 ->
        return_visit(ctx)

      true ->
        ctx
        |> mes("Strange looking stems are entangled inside an opening of huge roots.")
        |> mes("Surface looks unstable...I should step away before I slip on it.")
        |> close()
    end
  end

  defp first_visit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("There's a stem entangled inside an opening in the roots of a huge tree...")
      |> mes("It looks like something slipped here.")
      |> next()
      |> mes("A cold breeze is blowing out from deep inside the tree.")
      |> next()
      |> select(["Follow the trace.", "Looks dangerous... head back."])

    case choice do
      1 ->
        ctx
        |> mes("You take a one step forward carefully through the muddy roots and slip.")
        |> set_char_var(:ep13_mdrama, 6)
        |> close()
        |> percent_heal(hp: -30, sp: 0)
        |> warp("nyd_dun01", 72, 125)

      2 ->
        ctx
        |> mes(
          "It's too dark to see anything inside...but it feels like there's a big hole at the bottom."
        )
        |> mes("I'd better step back...It looks dangerous.")
        |> close()

      _ ->
        ctx
    end
  end

  defp return_visit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Between huge roots, there is a hole leads to the underground cave.")
      |> next()
      |> select(["Go inside.", "I'm not going in there."])

    case choice do
      1 ->
        ctx
        |> mes("Again, you slip through the muddy roots.")
        |> close()
        |> percent_heal(hp: -30, sp: 0)
        |> warp("nyd_dun01", 72, 125)

      2 ->
        ctx |> mes("You decide to come back later.") |> close()

      _ ->
        ctx
    end
  end
end
